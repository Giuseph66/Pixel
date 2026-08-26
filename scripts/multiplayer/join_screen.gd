class_name JoinScreen
extends Menu

signal joined

var player_name := "JOGADOR"
var room_code := ""
var signal_url := ""
var address := "127.0.0.1"
var port := SessionManager.DEFAULT_PORT
var password := ""
var color_index := 1
var online := true
var message := ""
var _editing := ""
var _input_cooldown := 0.0
var _joining := false


func _ready() -> void:
	super()
	title = "ENTRAR NA SALA"
	footer = "CIMA/BAIXO SELECIONA  ESQ/DIR MUDA  ESPACO EDITA"
	allow_cancel = true
	list_top = 66.0
	line_height = 17.0
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
	if online and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and _paste_button_rect().grow(3.0).has_point(event.position):
		_paste_room_code()
		_editing = ""
		_input_cooldown = 0.12
		get_viewport().set_input_as_handled()
		return
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
	var limit := 64 if _editing == "endpoint" else 32
	if event.unicode >= 32 and event.unicode <= 126 and _value(_editing).length() < limit:
		var typed := char(event.unicode)
		var keep_case := _editing == "endpoint" or _editing == "address"
		_set_text(_editing, _value(_editing) + (typed if keep_case else typed.to_upper()))


func _activate() -> void:
	var id := str(items[cursor]["id"])
	match id:
		"name", "code", "endpoint", "address", "password":
			_editing = id
		"join":
			_join_room()
		"back":
			cancelled.emit()
	_refresh()


func _join_room() -> void:
	_joining = true
	message = "CONECTANDO..."
	var profile := {"name": player_name, "color": color_index}
	var err := Session.join_online(room_code, profile, password, signal_url) if online else Session.join_lan(address, port, profile, password)
	if err != OK:
		_joining = false
		message = "CONEXAO FALHOU"


func _change(step: int) -> void:
	var id := str(items[cursor]["id"])
	if id == "connection":
		online = not online
	elif id == "port" and not online:
		port = clampi(port + step, 1024, 65535)
	elif id == "color":
		color_index = wrapi(color_index + step, 0, Player.PLAYER_COLORS.size())
	_refresh()


func _value(id: String) -> String:
	match id:
		"name": return player_name
		"code": return room_code
		"endpoint": return signal_url
		"address": return address
		"password": return password
	return ""


func _set_text(id: String, value: String) -> void:
	match id:
		"name": player_name = value
		"code": room_code = value
		"endpoint": signal_url = value
		"address": address = value
		"password": password = value
	_refresh()


func _paste_button_rect() -> Rect2:
	return Rect2(450.0, list_top + line_height * 2.0 - 3.0, 18.0, 16.0)


func _paste_room_code() -> void:
	var copied := DisplayServer.clipboard_get().strip_edges().to_upper()
	if copied.is_empty():
		message = "AREA DE TRANSFERENCIA VAZIA"
		return
	room_code = copied.left(32)
	message = "CODIGO COLADO"
	_refresh()


func _draw_paste_button() -> void:
	if not online:
		return
	var rect := _paste_button_rect()
	var hover := rect.grow(3.0).has_point(get_local_mouse_position())
	Util.draw_panel(self, rect, Palette.BG_SOFT, Palette.CYAN if hover else Palette.GREY_DARK)
	var ink := Palette.WHITE if hover else Palette.GREY
	draw_rect(Rect2(rect.position + Vector2(4.0, 5.0), Vector2(6.0, 7.0)), ink, false, 1.0)
	draw_rect(Rect2(rect.position + Vector2(7.0, 3.0), Vector2(6.0, 7.0)), ink, false, 1.0)


func _on_session_state(next: int, _reason: String) -> void:
	if _joining and next == SessionManager.State.LOBBY:
		_joining = false
		joined.emit()


func _on_join_failed(reason: String) -> void:
	if not _joining:
		return
	_joining = false
	message = {
		"BAD_PASSWORD": "SENHA INCORRETA",
		"ROOM_FULL": "SALA CHEIA",
		"ROOM_NOT_FOUND": "SALA NAO ENCONTRADA",
		"CONTENT_MISMATCH": "CONTEUDO DIFERENTE",
		"WEBRTC_UNAVAILABLE": "WEBRTC NAO INSTALADO",
		"NETWORK_FAILED": "SERVIDOR INDISPONIVEL",
	}.get(reason, "CONEXAO FALHOU")
	Session.leave()
	_refresh()


func _endpoint_label() -> String:
	if not online:
		return "LAN"
	return signal_url if signal_url.length() <= 24 else "..." + signal_url.right(21)


func _refresh() -> void:
	_rebuild_items()
	set_item_value("name", player_name + ("_" if _editing == "name" else ""))
	set_item_value("connection", "ONLINE" if online else "LAN")
	if online:
		set_item_value("code", room_code + ("_" if _editing == "code" else ""))
		set_item_value("endpoint", _endpoint_label() + ("_" if _editing == "endpoint" else ""))
	else:
		set_item_value("address", address + ("_" if _editing == "address" else ""))
		set_item_value("port", str(port))
	set_item_value("color", Player.player_color_name(color_index))
	set_item_value("password", "*".repeat(password.length()) + ("_" if _editing == "password" else "") if not password.is_empty() else "SEM SENHA")
	queue_redraw()


func _rebuild_items() -> void:
	var selected_id := str(items[cursor].get("id", "name")) if not items.is_empty() else "name"
	items = [
		{"id": "name", "label": "SEU NOME", "value": player_name},
		{"id": "connection", "label": "CONEXAO", "value": "ONLINE" if online else "LAN"},
	]
	if online:
		items.append_array([
			{"id": "code", "label": "CODIGO DA SALA", "value": room_code},
			{"id": "endpoint", "label": "SERVIDOR", "value": signal_url},
		])
	else:
		items.append_array([
			{"id": "address", "label": "IP DO HOST", "value": address},
			{"id": "port", "label": "PORTA LAN", "value": str(port)},
		])
	items.append_array([
		{"id": "color", "label": "SUA COR", "value": "ROSA"},
		{"id": "password", "label": "SENHA DA SALA", "value": "SEM SENHA"},
		{"id": "join", "label": "ENTRAR"},
		{"id": "back", "label": "VOLTAR"},
	])
	for i: int in items.size():
		if str(items[i].get("id", "")) == selected_id:
			cursor = i
			return
	cursor = clampi(cursor, 0, maxi(items.size() - 1, 0))


## draw_header() runs before the title (see Menu._draw()), and the title
## sits scale-3 across y 34-55 — a status line inside that band draws behind
## the title's own glyphs instead of above or below them. The band above the
## title is otherwise empty, so the message goes there instead.
func draw_header() -> void:
	if not message.is_empty():
		PixelFont.draw_text_centered(self, message, SCREEN.x * 0.5, 8.0, Palette.MAGENTA, 1)


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
	if online and str(item["id"]) == "code":
		_draw_paste_button()
