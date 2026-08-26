class_name HostScreen
extends Menu

signal created

const MODES := ["story", "endless", "competitive", "sandbox"]

var player_name := "JOGADOR"
var room_name := "SALA"
var password := ""
var max_players := 4
var mode_index := 0
var level_index := 0
var color_index := 0
var port := SessionManager.DEFAULT_PORT
var online := true
var signal_url := ""
var message := ""
var _editing := ""
var _input_cooldown := 0.0
var _opening := false


func _ready() -> void:
	super()
	title = "CRIAR SALA"
	footer = "CIMA/BAIXO SELECIONA  ESQ/DIR MUDA  ESPACO EDITA"
	allow_cancel = true
	list_top = 54.0
	line_height = 16.0
	item_scale = 1
	signal_url = Session.online_endpoint()
	Session.state_changed.connect(_on_session_state)
	Session.join_failed.connect(_on_join_failed)
	_refresh()


func _exit_tree() -> void:
	if Session.state_changed.is_connected(_on_session_state):
		Session.state_changed.disconnect(_on_session_state)
	if Session.join_failed.is_connected(_on_join_failed):
		Session.join_failed.disconnect(_on_join_failed)


func _process(delta: float) -> void:
	_input_cooldown = maxf(0.0, _input_cooldown - delta)
	super(delta)


func _handle_input() -> void:
	if _input_cooldown > 0.0:
		return
	if not _editing.is_empty():
		if Input.is_action_just_pressed("p_cancel"):
			_editing = ""
			_refresh()
		return
	if Input.is_action_just_pressed("p_up"):
		_move(-1)
	elif Input.is_action_just_pressed("p_down"):
		_move(1)
	elif Input.is_action_just_pressed("p_left"):
		_change(-1)
	elif Input.is_action_just_pressed("p_right"):
		_change(1)
	elif Input.is_action_just_pressed("p_accept"):
		_activate()
	elif Input.is_action_just_pressed("p_cancel"):
		cancelled.emit()


func _input(event: InputEvent) -> void:
	if _editing.is_empty() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_editing = ""
		_input_cooldown = 0.12
		_refresh()
		return
	if event.keycode == KEY_BACKSPACE:
		var current := _value(_editing)
		_set_text(_editing, current.substr(0, maxi(current.length() - 1, 0)))
		return
	var limit := 64 if _editing == "endpoint" else 16
	if event.unicode >= 32 and event.unicode <= 126 and _value(_editing).length() < limit:
		var typed := char(event.unicode)
		_set_text(_editing, _value(_editing) + (typed if _editing == "endpoint" else typed.to_upper()))


func _activate() -> void:
	var id := str(items[cursor]["id"])
	match id:
		"name", "room", "password", "endpoint":
			_editing = id
		"create":
			_open_room()
		"back":
			cancelled.emit()
	_refresh()


func _open_room() -> void:
	Session.local_profile = {"name": player_name, "color": color_index}
	var room_data: Dictionary = {}
	if MODES[mode_index] == "sandbox":
		var rooms := Sandbox.all()
		room_data = (rooms[0] if not rooms.is_empty() else Sandbox.blank_room()).duplicate(true)
	var values := {
		"room_name": room_name,
		"mode": MODES[mode_index],
		"level_index": level_index,
		"max_players": max_players,
		"port": port,
		"password_required": not password.is_empty(),
		"room_data": room_data,
	}
	_opening = true
	message = "ABRINDO SALA..."
	var err := Session.host_online(values, password, signal_url) if online else Session.host_lan(values, password)
	if err != OK:
		_opening = false
		message = "NAO FOI POSSIVEL ABRIR A SALA"


func _change(step: int) -> void:
	var id := str(items[cursor]["id"])
	if id == "connection":
		online = not online
	elif id == "mode":
		mode_index = wrapi(mode_index + step, 0, MODES.size())
	elif id == "color":
		color_index = wrapi(color_index + step, 0, Player.PLAYER_COLORS.size())
	elif id == "level":
		level_index = wrapi(level_index + step, 0, Levels.count())
	elif id == "capacity":
		max_players = clampi(max_players + step, SessionConfig.MIN_PLAYERS, SessionConfig.MAX_PLAYERS)
	elif id == "port" and not online:
		port = clampi(port + step, 1024, 65535)
	_refresh()


func _value(id: String) -> String:
	match id:
		"name": return player_name
		"room": return room_name
		"password": return password
		"endpoint": return signal_url
	return ""


func _set_text(id: String, value: String) -> void:
	match id:
		"name": player_name = value
		"room": room_name = value
		"password": password = value
		"endpoint": signal_url = value
	_refresh()


func _on_session_state(next: int, _reason: String) -> void:
	if _opening and next == SessionManager.State.LOBBY:
		_opening = false
		created.emit()


func _on_join_failed(reason: String) -> void:
	if not _opening:
		return
	_opening = false
	message = {
		"WEBRTC_UNAVAILABLE": "WEBRTC NAO INSTALADO",
		"NETWORK_FAILED": "SERVIDOR INDISPONIVEL",
	}.get(reason, "NAO FOI POSSIVEL ABRIR A SALA")
	_refresh()


func _endpoint_label() -> String:
	if not online:
		return "LAN"
	return signal_url if signal_url.length() <= 24 else "..." + signal_url.right(21)


func _refresh() -> void:
	_rebuild_items()
	set_item_value("name", player_name + ("_" if _editing == "name" else ""))
	set_item_value("room", room_name + ("_" if _editing == "room" else ""))
	set_item_value("connection", "ONLINE" if online else "LAN")
	if online:
		set_item_value("endpoint", _endpoint_label() + ("_" if _editing == "endpoint" else ""))
	else:
		set_item_value("port", str(port))
	set_item_value("color", Player.player_color_name(color_index))
	set_item_value("mode", ["HISTORIA", "INFINITO", "CORRIDA", "SANDBOX"][mode_index])
	set_item_value("level", "%02d" % (level_index + 1))
	set_item_value("capacity", str(max_players))
	set_item_value("password", "*".repeat(password.length()) + ("_" if _editing == "password" else "") if not password.is_empty() else "SEM SENHA")
	queue_redraw()


func _rebuild_items() -> void:
	var selected_id := str(items[cursor].get("id", "name")) if not items.is_empty() else "name"
	items = [
		{"id": "name", "label": "SEU NOME", "value": player_name},
		{"id": "room", "label": "NOME DA SALA", "value": room_name},
		{"id": "connection", "label": "CONEXAO", "value": "ONLINE" if online else "LAN"},
	]
	if online:
		items.append({"id": "endpoint", "label": "SERVIDOR", "value": signal_url})
	else:
		items.append({"id": "port", "label": "PORTA LAN", "value": str(port)})
	items.append_array([
		{"id": "color", "label": "SUA COR", "value": "AZUL"},
		{"id": "mode", "label": "MODO", "value": "HISTORIA"},
		{"id": "level", "label": "FASE INICIAL", "value": "01"},
		{"id": "capacity", "label": "MAX JOGADORES", "value": str(max_players)},
		{"id": "password", "label": "SENHA DA SALA", "value": "SEM SENHA"},
		{"id": "create", "label": "CRIAR SALA"},
		{"id": "back", "label": "VOLTAR"},
	])
	for i: int in items.size():
		if str(items[i].get("id", "")) == selected_id:
			cursor = i
			return
	cursor = clampi(cursor, 0, maxi(items.size() - 1, 0))


func draw_header() -> void:
	if not message.is_empty():
		PixelFont.draw_text_centered(self, message, SCREEN.x * 0.5, 42.0, Palette.MAGENTA, 1)


func _draw_item(i: int) -> void:
	var item: Dictionary = items[i]
	var y := list_top + i * line_height
	var selected := i == cursor
	var label := str(item["label"])
	var value := str(item.get("value", ""))
	var color := Palette.WHITE if selected else Palette.GREY
	if selected:
		draw_rect(Rect2(42.0, y - 2.0, 396.0, 13.0), Palette.BG_SOFT)
		PixelFont.draw_text(self, ">", Vector2(30.0, y), Palette.MAGENTA, 1)
	PixelFont.draw_text(self, label, Vector2(54.0, y), color, 1)
	if not value.is_empty():
		var size := PixelFont.measure(value, 1)
		var value_color := Player.player_color(color_index) if str(item["id"]) == "color" else color
		PixelFont.draw_text(self, value, Vector2(438.0 - size.x, y), value_color, 1)
