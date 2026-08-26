class_name SessionManager
extends Node

## Network boundary. Gameplay only asks whether a session is active, who is in
## it, and which input frame belongs to a peer. ENet is deliberately contained
## here so a WebRTC transport can replace the connection layer later.

signal state_changed(state: int, reason: String)
signal roster_changed(participants: Dictionary)
signal config_changed(config: Dictionary)
signal join_failed(reason: String)
signal game_start_requested(config: Dictionary)
signal snapshot_received(snapshot: Dictionary)
signal world_event_received(event: Dictionary)
signal client_state_received(peer_id: int, snapshot: Dictionary)
signal player_event_received(peer_id: int, kind: String, payload: Dictionary)
signal lobby_requested
signal host_left

const PROTOCOL_VERSION := 4
const DEFAULT_PORT := 27816

enum State { OFFLINE, CONNECTING, LOBBY, LOADING, PLAYING, FAILED }
enum Role { NONE, HOST, CLIENT }

var state := State.OFFLINE
var role := Role.NONE
var config: Dictionary = {}
var participants: Dictionary = {}
var local_profile := {"name": "PLAYER", "color": 0}

var _password_digest := ""
var _join_password := ""
var _server_nonce := ""
var _nonces: Dictionary = {}
var _inputs: Dictionary = {}
var _transport: NetworkTransport
var _event_id := 0
var _received_events: Dictionary = {}
var _server_capacity := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_transport = EnetTransport.new()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_active() -> bool:
	return role != Role.NONE and state != State.OFFLINE


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


func local_peer_id() -> int:
	return multiplayer.get_unique_id() if is_active() else 1


func host_lan(values: Dictionary, password: String = "") -> Error:
	leave()
	var max_players := clampi(int(values.get("max_players", 4)),
		SessionConfig.MIN_PLAYERS, SessionConfig.MAX_PLAYERS)
	var port := clampi(int(values.get("port", DEFAULT_PORT)), 1024, 65535)
	var err := _transport.host(port, max_players - 1)
	if err != OK:
		_fail("HOST_FAILED")
		return err

	multiplayer.multiplayer_peer = _transport.peer
	role = Role.HOST
	_password_digest = _hash(password)
	config = SessionConfig.make(values)
	config["max_players"] = max_players
	_server_capacity = max_players
	config["content_hash"] = content_hash()
	config["room_code"] = _room_code()
	if config.get("room_data", {}) is Dictionary and not config["room_data"].is_empty():
		config["room_data_hash"] = _hash(JSON.stringify(config["room_data"]))
	participants = {1: _participant(local_profile, true)}
	_inputs = {1: {}}
	_event_id = 0
	_received_events = {}
	_set_state(State.LOBBY)
	NetworkLog.event("host", 1, state, "lobby opened")
	roster_changed.emit(participants.duplicate(true))
	return OK


func join_lan(address: String, port: int, profile: Dictionary, password: String = "") -> Error:
	leave()
	var err := _transport.join(address.strip_edges(), clampi(port, 1024, 65535))
	if err != OK:
		_fail("CONNECT_FAILED")
		return err

	local_profile = _profile(profile)
	_join_password = password
	multiplayer.multiplayer_peer = _transport.peer
	role = Role.CLIENT
	_set_state(State.CONNECTING)
	return OK


func leave() -> void:
	if _transport != null:
		_transport.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	state = State.OFFLINE
	role = Role.NONE
	config = {}
	participants = {}
	_inputs = {}
	_password_digest = ""
	_join_password = ""
	_server_nonce = ""
	_nonces = {}
	_event_id = 0
	_received_events = {}
	_server_capacity = 0
	state_changed.emit(state, "")


func start_game() -> bool:
	if not is_host() or state != State.LOBBY or not everyone_ready():
		return false
	_set_state(State.LOADING)
	game_started.rpc(config)
	game_start_requested.emit(config.duplicate(true))
	return true


func mark_playing() -> void:
	if is_active():
		_set_state(State.PLAYING)


func return_to_lobby() -> void:
	if not is_host() or state != State.PLAYING:
		return
	_reset_ready()
	_set_state(State.LOBBY)
	game_returned.rpc(config, participants)
	lobby_requested.emit()


func advance_story(next_level_index: int) -> bool:
	if not is_host() or state != State.PLAYING or str(config.get("mode", "")) != "story":
		return false
	config["level_index"] = maxi(0, next_level_index)
	_set_state(State.LOADING)
	game_started.rpc(config)
	game_start_requested.emit(config.duplicate(true))
	return true


@rpc("authority", "call_remote", "reliable")
func game_returned(host_config: Dictionary, host_participants: Dictionary) -> void:
	if not is_client():
		return
	config = host_config.duplicate(true)
	participants = host_participants.duplicate(true)
	_set_state(State.LOBBY)
	roster_changed.emit(participants.duplicate(true))
	lobby_requested.emit()


func send_input(frame: Dictionary) -> void:
	if not is_active() or state != State.PLAYING:
		return
	if is_host():
		_store_input(1, frame)
	else:
		receive_input.rpc_id(1, frame)


## Clients own their immediate movement. The host trusts this state, resolves
## shared world interactions from it, then relays it to the other screens.
func publish_client_state(snapshot: Dictionary) -> void:
	if is_client() and state == State.PLAYING:
		receive_client_state.rpc_id(1, snapshot)


func publish_player_event(kind: String, payload: Dictionary = {}) -> void:
	if is_client() and state == State.PLAYING:
		receive_player_event.rpc_id(1, kind, payload)


func input_for(peer_id: int) -> Dictionary:
	return _inputs.get(peer_id, {})


func everyone_ready() -> bool:
	if participants.is_empty():
		return false
	for participant: Dictionary in participants.values():
		if not bool(participant.get("ready", false)):
			return false
	return true


func capacity_limit() -> int:
	return _server_capacity if is_host() else SessionConfig.MAX_PLAYERS


func set_ready(ready: bool) -> void:
	if state != State.LOBBY:
		return
	if is_host():
		_set_participant_ready(1, ready)
		return
	if is_client():
		send_ready_state.rpc_id(1, ready)


func update_lobby(changes: Dictionary) -> void:
	if not is_host() or state != State.LOBBY:
		return
	if changes.has("mode"):
		config["mode"] = str(changes["mode"])
	if changes.has("level_index"):
		config["level_index"] = maxi(0, int(changes["level_index"]))
	if changes.has("seed"):
		config["seed"] = int(changes["seed"])
	if changes.has("room_data") and changes["room_data"] is Dictionary:
		config["room_data"] = changes["room_data"].duplicate(true)
		config["room_data_hash"] = _hash(JSON.stringify(config["room_data"]))
	if changes.has("max_players"):
		config["max_players"] = clampi(int(changes["max_players"]),
			maxi(participants.size(), SessionConfig.MIN_PLAYERS), capacity_limit())
	sync_config.rpc(config)
	config_changed.emit(config.duplicate(true))


func kick(peer_id: int) -> void:
	if not is_host() or state != State.LOBBY or peer_id == 1:
		return
	if participants.erase(peer_id):
		_inputs.erase(peer_id)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		sync_roster.rpc(participants)
		roster_changed.emit(participants.duplicate(true))


func publish_snapshot(snapshot: Dictionary) -> void:
	if is_host() and state == State.PLAYING:
		receive_snapshot.rpc(snapshot)


func publish_world_event(kind: String, payload: Dictionary = {}) -> void:
	if not is_host() or state != State.PLAYING:
		return
	_event_id += 1
	var event := {
		"id": _event_id,
		"kind": kind,
		"payload": payload.duplicate(true),
	}
	receive_world_event.rpc(event)


@rpc("authority", "call_remote", "reliable", 0)
func receive_world_event(event: Dictionary) -> void:
	if not is_client() or state != State.PLAYING:
		return
	var event_id := int(event.get("id", -1))
	if event_id < 0 or _received_events.has(event_id):
		return
	_received_events[event_id] = true
	# Keep a small, bounded replay window for a reconnect/full-state extension.
	if _received_events.size() > 256:
		_received_events.erase(_received_events.keys().min())
	world_event_received.emit(event.duplicate(true))


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_snapshot(snapshot: Dictionary) -> void:
	if is_client() and state == State.PLAYING:
		snapshot_received.emit(snapshot)


func content_hash() -> String:
	var source := "protocol:%d\n" % PROTOCOL_VERSION
	for level: Dictionary in Levels.all():
		source += str(level.get("id", "")) + "\n"
		for row: String in level.get("rows", PackedStringArray()):
			source += row + "\n"
	return _hash(source)


func room_data_matches(room_data: Dictionary) -> bool:
	var expected := str(config.get("room_data_hash", ""))
	return expected.is_empty() or expected == _hash(JSON.stringify(room_data))


@rpc("authority", "call_remote", "reliable")
func server_hello(nonce: String, host_config: Dictionary) -> void:
	if not is_client() or state != State.CONNECTING:
		return
	if int(host_config.get("protocol", -1)) != PROTOCOL_VERSION:
		_fail("PROTOCOL_MISMATCH")
		return
	if str(host_config.get("content_hash", "")) != content_hash():
		_fail("CONTENT_MISMATCH")
		return
	_server_nonce = nonce
	var base := _hash(_join_password)
	var proof := _hash(base + nonce)
	request_join.rpc_id(1, local_profile, PROTOCOL_VERSION, content_hash(), proof)


@rpc("any_peer", "call_remote", "reliable")
func request_join(profile: Dictionary, protocol: int, remote_hash: String, proof: String) -> void:
	if not is_host() or state != State.LOBBY:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL_VERSION:
		join_rejected.rpc_id(peer_id, "PROTOCOL_MISMATCH")
		return
	if remote_hash != str(config.get("content_hash", "")):
		join_rejected.rpc_id(peer_id, "CONTENT_MISMATCH")
		return
	if participants.size() >= int(config.get("max_players", 0)):
		join_rejected.rpc_id(peer_id, "ROOM_FULL")
		return
	if proof != _hash(_password_digest + str(_nonces.get(peer_id, ""))):
		join_rejected.rpc_id(peer_id, "BAD_PASSWORD")
		return

	participants[peer_id] = _participant(profile, false)
	_inputs[peer_id] = {}
	join_accepted.rpc_id(peer_id, config, participants)
	sync_roster.rpc(participants)
	roster_changed.emit(participants.duplicate(true))


@rpc("authority", "call_remote", "reliable")
func join_accepted(host_config: Dictionary, host_participants: Dictionary) -> void:
	if not is_client():
		return
	config = host_config.duplicate(true)
	participants = host_participants.duplicate(true)
	_inputs = {}
	_set_state(State.LOBBY)
	roster_changed.emit(participants.duplicate(true))


@rpc("authority", "call_remote", "reliable")
func join_rejected(reason: String) -> void:
	if not is_client():
		return
	_fail(reason)


@rpc("authority", "call_remote", "reliable")
func sync_roster(host_participants: Dictionary) -> void:
	if not is_client():
		return
	participants = host_participants.duplicate(true)
	roster_changed.emit(participants.duplicate(true))


@rpc("authority", "call_remote", "reliable")
func sync_config(host_config: Dictionary) -> void:
	if not is_client() or state != State.LOBBY:
		return
	config = host_config.duplicate(true)
	config_changed.emit(config.duplicate(true))


@rpc("any_peer", "call_remote", "reliable")
func send_ready_state(ready: bool) -> void:
	if not is_host() or state != State.LOBBY:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not participants.has(peer_id):
		return
	_set_participant_ready(peer_id, ready)


@rpc("authority", "call_remote", "reliable")
func game_started(host_config: Dictionary) -> void:
	if not is_client() or (state != State.LOBBY and state != State.PLAYING):
		return
	config = host_config.duplicate(true)
	_set_state(State.LOADING)
	game_start_requested.emit(config.duplicate(true))


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func receive_input(frame: Dictionary) -> void:
	if not is_host() or state != State.PLAYING:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not participants.has(peer_id):
		return
	_store_input(peer_id, frame)


@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func receive_client_state(snapshot: Dictionary) -> void:
	if not is_host() or state != State.PLAYING:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not participants.has(peer_id):
		return
	client_state_received.emit(peer_id, snapshot.duplicate(true))


@rpc("any_peer", "call_remote", "reliable", 4)
func receive_player_event(kind: String, payload: Dictionary) -> void:
	if not is_host() or state != State.PLAYING:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not participants.has(peer_id):
		return
	player_event_received.emit(peer_id, kind, payload.duplicate(true))


func _on_peer_connected(peer_id: int) -> void:
	if not is_host() or state != State.LOBBY:
		return
	var nonce := _hash("%s:%d:%d" % [Time.get_ticks_usec(), peer_id, randi()])
	_nonces[peer_id] = nonce
	server_hello.rpc_id(peer_id, nonce, config)


func _on_peer_disconnected(peer_id: int) -> void:
	if is_host():
		_nonces.erase(peer_id)
		_inputs.erase(peer_id)
		if participants.erase(peer_id):
			sync_roster.rpc(participants)
			roster_changed.emit(participants.duplicate(true))
			NetworkLog.event("host", peer_id, state, "peer left")


func _on_connected_to_server() -> void:
	# The host sends the nonce next. Keeping this state distinct lets the UI show
	# "autenticando" rather than pretending the room is already joined.
	if is_client():
		_set_state(State.CONNECTING)


func _on_connection_failed() -> void:
	if is_client():
		_fail("CONNECT_FAILED")


func _on_server_disconnected() -> void:
	if not is_client():
		return
	host_left.emit()
	leave()


func _set_state(next: int, reason: String = "") -> void:
	state = next
	state_changed.emit(state, reason)
	NetworkLog.event("host" if is_host() else "client", local_peer_id(), state, reason)


func _fail(reason: String) -> void:
	_set_state(State.FAILED, reason)
	join_failed.emit(reason)


func _store_input(peer_id: int, raw: Dictionary) -> void:
	var previous: Dictionary = _inputs.get(peer_id, {})
	var frame := {
		"left": bool(raw.get("left", false)),
		"right": bool(raw.get("right", false)),
		"up": bool(raw.get("up", false)),
		"down": bool(raw.get("down", false)),
		"dash": bool(raw.get("dash", false)),
		"jump": bool(raw.get("jump", false)),
	}
	frame["jump_pressed"] = bool(frame["jump"]) and not bool(previous.get("jump", false))
	frame["jump_released"] = not bool(frame["jump"]) and bool(previous.get("jump", false))
	_inputs[peer_id] = frame


func _profile(values: Dictionary) -> Dictionary:
	var name := str(values.get("name", "PLAYER")).strip_edges().to_upper()
	if name.is_empty():
		name = "PLAYER"
	return {
		"name": name.left(12),
		"color": posmod(int(values.get("color", 0)), 8),
	}


func _participant(profile: Dictionary, ready: bool) -> Dictionary:
	var participant := _profile(profile)
	participant["ready"] = ready
	return participant


func _set_participant_ready(peer_id: int, ready: bool) -> void:
	if not participants.has(peer_id):
		return
	var participant: Dictionary = participants[peer_id]
	participant["ready"] = ready
	participants[peer_id] = participant
	sync_roster.rpc(participants)
	roster_changed.emit(participants.duplicate(true))


func _reset_ready() -> void:
	for peer_id: int in participants.keys():
		_set_participant_ready(peer_id, false)


func _hash(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	var bytes := text.to_utf8_buffer()
	if not bytes.is_empty():
		context.update(bytes)
	return context.finish().hex_encode()


func _room_code() -> String:
	const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in 8:
		if i == 4:
			code += "-"
		code += ALPHABET[randi_range(0, ALPHABET.length() - 1)]
	return code
