class_name JoinScreen
extends Menu

signal joined

var player_name := "PLAYER"
var address := "127.0.0.1"
var port := SessionManager.DEFAULT_PORT
var password := ""
var message := ""
var _editing := ""
var _input_cooldown := 0.0


func _ready() -> void:
	super()
	title = "ENTRAR NA SALA"
	footer = "IP PARA LAN  ESC VOLTA"
	allow_cancel = true
	list_top = 78.0
	line_height = 20.0
	items = [
		{"id": "name", "label": "NOME", "value": player_name},
		{"id": "address", "label": "IP", "value": address},
		{"id": "port", "label": "PORTA", "value": str(port)},
		{"id": "password", "label": "SENHA", "value": "SEM SENHA"},
		{"id": "join", "label": "CONECTAR"},
		{"id": "back", "label": "VOLTAR"},
	]
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
		return
	if event.keycode == KEY_BACKSPACE:
		var current := _value(_editing)
		_set_text(_editing, current.substr(0, maxi(current.length() - 1, 0)))
		return
	if event.unicode >= 32 and event.unicode <= 126 and _value(_editing).length() < 32:
		_set_text(_editing, _value(_editing) + char(event.unicode).to_upper())


func _activate() -> void:
	var id := str(items[cursor]["id"])
	match id:
		"name", "address", "password":
			_editing = id
		"join":
			message = "CONECTANDO..."
			Session.join_lan(address, port, {"name": player_name, "color": 1}, password)
		"back":
			cancelled.emit()
	_refresh()


func _change(step: int) -> void:
	if str(items[cursor]["id"]) == "port":
		port = clampi(port + step, 1024, 65535)
	_refresh()


func _value(id: String) -> String:
	match id:
		"name": return player_name
		"address": return address
		"password": return password
	return ""


func _set_text(id: String, value: String) -> void:
	match id:
		"name": player_name = value
		"address": address = value
		"password": password = value
	_refresh()


func _refresh() -> void:
	set_item_value("name", player_name + ("_" if _editing == "name" else ""))
	set_item_value("address", address + ("_" if _editing == "address" else ""))
	set_item_value("port", str(port))
	set_item_value("password", "*".repeat(password.length()) + ("_" if _editing == "password" else "") if not password.is_empty() else "SEM SENHA")
	queue_redraw()


func _on_session_state(next: int, _reason: String) -> void:
	if next == SessionManager.State.LOBBY:
		joined.emit()


func _on_join_failed(reason: String) -> void:
	message = {
		"BAD_PASSWORD": "SENHA INCORRETA",
		"ROOM_FULL": "SALA CHEIA",
		"CONTENT_MISMATCH": "CONTEUDO DIFERENTE",
	}.get(reason, "CONEXAO FALHOU")
	Session.leave()
	_refresh()


func draw_header() -> void:
	if not message.is_empty():
		PixelFont.draw_text_centered(self, message, SCREEN.x * 0.5, 56.0, Palette.MAGENTA, 1)
