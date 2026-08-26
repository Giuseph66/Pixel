class_name SignalingClient
extends Node

## HTTPS room registry plus WebRTC negotiation. Gameplay never passes here.

signal room_created(session: Dictionary)
signal room_joined(session: Dictionary)
signal signals_received(messages: Array)
signal failed(reason: String)

const HEARTBEAT_SECONDS := 20.0

var endpoint := ""
var room_code := ""
var token := ""
var member: Dictionary = {}
var ice_servers: Array = []

var _active := false
var _polling := false
var _heartbeat_left := HEARTBEAT_SECONDS


func is_configured() -> bool:
	return not endpoint.strip_edges().is_empty()


func create_room(room_name: String, password: String, capacity: int) -> Error:
	if not is_configured():
		return ERR_UNAVAILABLE
	_request("/v1/rooms", HTTPClient.METHOD_POST, {
		"name": room_name,
		"password": password,
		"capacity": capacity,
	}, false, func(ok: bool, response: Dictionary) -> void:
		if not ok:
			failed.emit(_error_of(response, "HOST_FAILED"))
			return
		_open_session(response)
		room_created.emit(response)
	)
	return OK


func join_room(code: String, player_name: String, password: String) -> Error:
	if not is_configured():
		return ERR_UNAVAILABLE
	room_code = code.strip_edges().to_upper()
	_request("/v1/rooms/%s/join" % room_code, HTTPClient.METHOD_POST, {
		"name": player_name,
		"password": password,
	}, false, func(ok: bool, response: Dictionary) -> void:
		if not ok:
			failed.emit(_error_of(response, "CONNECT_FAILED"))
			return
		_open_session(response)
		room_joined.emit(response)
	)
	return OK


func send_signal(to: String, signal_type: String, data: Dictionary) -> void:
	if not _active or to.is_empty():
		return
	_request("/v1/rooms/%s/signal" % room_code, HTTPClient.METHOD_POST, {
		"to": to,
		"type": signal_type,
		"data": data,
	}, true, func(_ok: bool, _response: Dictionary) -> void: pass)


func leave() -> void:
	if not _active:
		return
	_active = false
	_polling = false
	if not room_code.is_empty() and not token.is_empty():
		_request("/v1/rooms/%s/leave" % room_code, HTTPClient.METHOD_POST, {}, true,
			func(_ok: bool, _response: Dictionary) -> void: pass)
	room_code = ""
	token = ""
	member = {}
	ice_servers = []


func _process(delta: float) -> void:
	if not _active:
		return
	_heartbeat_left -= delta
	if _heartbeat_left <= 0.0:
		_heartbeat_left = HEARTBEAT_SECONDS
		_request("/v1/rooms/%s/heartbeat" % room_code, HTTPClient.METHOD_POST, {}, true,
			func(ok: bool, response: Dictionary) -> void:
				if not ok and _active:
					failed.emit(_error_of(response, "SERVER_DISCONNECTED"))
		)
	if not _polling:
		_poll_signals()


func _open_session(session: Dictionary) -> void:
	var room: Dictionary = session.get("room", {})
	room_code = str(room.get("code", room_code)).to_upper()
	token = str(session.get("token", ""))
	member = Dictionary(session.get("member", {})).duplicate(true)
	var raw_ice_servers: Variant = session.get("ice_servers", [])
	ice_servers = []
	if raw_ice_servers is Array:
		ice_servers.assign(raw_ice_servers)
	_active = not room_code.is_empty() and not token.is_empty() and not member.is_empty()
	_heartbeat_left = HEARTBEAT_SECONDS


func _poll_signals() -> void:
	if not _active or _polling:
		return
	_polling = true
	_request("/v1/rooms/%s/signals" % room_code, HTTPClient.METHOD_GET, {}, true,
		func(ok: bool, response: Dictionary) -> void:
			_polling = false
			if not _active:
				return
			if not ok:
				failed.emit(_error_of(response, "SERVER_DISCONNECTED"))
				return
			var raw_messages: Variant = response.get("signals", [])
			var messages: Array = []
			if raw_messages is Array:
				messages.assign(raw_messages)
			if not messages.is_empty():
				signals_received.emit(messages)
			call_deferred("_poll_signals")
	)


func _request(path: String, method: int, payload: Dictionary, authenticated: bool,
		callback: Callable) -> void:
	var request := HTTPRequest.new()
	request.timeout = 25.0
	add_child(request)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray,
			body: PackedByteArray) -> void:
		request.queue_free()
		var response := _decode(body)
		var ok := result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
		if response.is_empty() and not ok:
			response = {"error": "NETWORK_FAILED"}
		callback.call(ok, response)
	)
	var headers := PackedStringArray(["Accept: application/json"])
	if method != HTTPClient.METHOD_GET:
		headers.append("Content-Type: application/json")
	if authenticated and not token.is_empty():
		headers.append("Authorization: Bearer %s" % token)
	var body := JSON.stringify(payload) if method != HTTPClient.METHOD_GET else ""
	var err := request.request(_url(path), headers, method, body)
	if err != OK:
		request.queue_free()
		callback.call_deferred(false, {"error": "NETWORK_FAILED"})


func _url(path: String) -> String:
	return endpoint.strip_edges().trim_suffix("/") + path


func _decode(body: PackedByteArray) -> Dictionary:
	if body.is_empty():
		return {}
	var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
	return Dictionary(decoded) if decoded is Dictionary else {}


func _error_of(response: Dictionary, fallback: String) -> String:
	return str(response.get("error", fallback))
