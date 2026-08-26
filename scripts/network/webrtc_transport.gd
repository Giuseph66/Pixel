class_name WebRtcTransport
extends NetworkTransport

## WebRTC keeps Godot's MultiplayerPeer/RPC layer intact. The Go service only
## exchanges SDP/ICE; players send game packets directly or through TURN.

signal signal_outgoing(to: String, signal_type: String, data: Dictionary)

## Transfer channels used by SessionManager RPCs. Channel zero is created by
## WebRTCMultiplayerPeer itself; this array declares channels 1 through 4.
## Host and client must use the exact same order and transfer modes.
const EXTRA_CHANNELS := [
	MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, # 1: client input
	MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, # 2: host snapshots
	MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, # 3: client state
	MultiplayerPeer.TRANSFER_MODE_RELIABLE,           # 4: player events
]

var _web_rtc: WebRTCMultiplayerPeer
var _ice_servers: Array = []
var _connections: Dictionary = {}
var _members: Dictionary = {}


func host(_port: int, _max_clients: int) -> Error:
	return open_host([])


func join(_address: String, _port: int) -> Error:
	return ERR_UNAVAILABLE


func open_host(ice_servers: Array) -> Error:
	close()
	_ice_servers = ice_servers.duplicate(true)
	var native_error := _validate_native()
	if native_error != OK:
		return native_error
	_web_rtc = WebRTCMultiplayerPeer.new()
	var err := _web_rtc.create_server(EXTRA_CHANNELS)
	if err == OK:
		peer = _web_rtc
	return err


func open_client(local_id: int, host_member: Dictionary, ice_servers: Array) -> Error:
	close()
	_ice_servers = ice_servers.duplicate(true)
	var native_error := _validate_native()
	if native_error != OK:
		return native_error
	_web_rtc = WebRTCMultiplayerPeer.new()
	var err := _web_rtc.create_client(local_id, EXTRA_CHANNELS)
	if err != OK:
		return err
	peer = _web_rtc
	return _open_connection(host_member, false)


func host_peer_joined(member: Dictionary) -> Error:
	return _open_connection(member, true)


func handle_signal(from: String, signal_type: String, data: Dictionary) -> void:
	if signal_type == "bye":
		_close_member(from)
		return
	var connection: WebRTCPeerConnection = _connections.get(from)
	if connection == null:
		return
	match signal_type:
		"offer":
			if connection.set_remote_description("offer", str(data.get("sdp", ""))) == OK:
				connection.create_answer()
		"answer":
			connection.set_remote_description("answer", str(data.get("sdp", "")))
		"candidate":
			connection.add_ice_candidate(str(data.get("media", "")), int(data.get("index", 0)),
				str(data.get("candidate", "")))


func register_member(member: Dictionary) -> void:
	var id := str(member.get("id", ""))
	if not id.is_empty():
		_members[id] = member.duplicate(true)


func poll() -> void:
	for connection: WebRTCPeerConnection in _connections.values():
		connection.poll()


func close() -> void:
	for member_id: String in _connections.keys():
		_close_member(member_id)
	_connections.clear()
	_members.clear()
	_ice_servers = []
	_web_rtc = null
	super()


func _open_connection(member: Dictionary, offer: bool) -> Error:
	if _web_rtc == null:
		return ERR_UNAVAILABLE
	var member_id := str(member.get("id", ""))
	var peer_id := int(member.get("peer_id", 0))
	if member_id.is_empty() or peer_id < 1:
		return ERR_INVALID_PARAMETER
	if _connections.has(member_id):
		return OK
	register_member(member)
	var connection := WebRTCPeerConnection.new()
	var err := connection.initialize({"iceServers": _ice_servers})
	if err != OK:
		return err
	connection.session_description_created.connect(
		func(kind: String, sdp: String) -> void:
			connection.set_local_description(kind, sdp)
			signal_outgoing.emit(member_id, kind, {"sdp": sdp})
	)
	connection.ice_candidate_created.connect(
		func(media: String, index: int, candidate: String) -> void:
			signal_outgoing.emit(member_id, "candidate", {
				"media": media, "index": index, "candidate": candidate,
			})
	)
	err = _web_rtc.add_peer(connection, peer_id)
	if err != OK:
		connection.close()
		return err
	_connections[member_id] = connection
	if offer:
		connection.create_offer()
	return OK


func _validate_native() -> Error:
	var probe := WebRTCPeerConnection.new()
	var err := probe.initialize({"iceServers": _ice_servers})
	probe.close()
	return err


func _close_member(member_id: String) -> void:
	var connection: WebRTCPeerConnection = _connections.get(member_id)
	if connection != null:
		connection.close()
	_connections.erase(member_id)
	_members.erase(member_id)
