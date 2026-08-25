class_name HostScreen
extends Menu

signal created

const MODES := ["story", "endless", "competitive", "sandbox"]

var player_name := "HOST"
var room_name := "SALA"
var password := ""
var max_players := 4
var mode_index := 0
var level_index := 0
var port := SessionManager.DEFAULT_PORT
var message := ""
var _editing := ""
var _input_cooldown := 0.0


func _ready() -> void:
	super()
	title = "CRIAR SALA"
	footer = "ESQ/DIR ALTERA  ESPACO EDITA"
	allow_cancel = true
	list_top = 70.0
	line_height = 18.0
	items = [
		{"id": "name", "label": "NOME", "value": player_name},
		{"id": "room", "label": "SALA", "value": room_name},
		{"id": "mode", "label": "MODO", "value": "HISTORIA"},
		{"id": "level", "label": "SALA INICIAL", "value": "01"},
		{"id": "capacity", "label": "CAPACIDADE", "value": str(max_players)},
		{"id": "password", "label": "SENHA", "value": "SEM SENHA"},
		{"id": "create", "label": "CRIAR"},
		{"id": "back", "label": "VOLTAR"},
	]
	_refresh()


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
	if event.unicode >= 32 and event.unicode <= 126 and _value(_editing).length() < 16:
		_set_text(_editing, _value(_editing) + char(event.unicode).to_upper())


func _activate() -> void:
	var id := str(items[cursor]["id"])
	match id:
		"name", "room", "password":
			_editing = id
		"create":
			Session.local_profile = {"name": player_name, "color": 0}
			var room_data: Dictionary = {}
			if MODES[mode_index] == "sandbox":
				var rooms := Sandbox.all()
				room_data = (rooms[0] if not rooms.is_empty() else Sandbox.blank_room()).duplicate(true)
			var err := Session.host_lan({
				"room_name": room_name,
				"mode": MODES[mode_index],
				"level_index": level_index,
				"max_players": max_players,
				"port": port,
				"password_required": not password.is_empty(),
			}, password)
			if err == OK:
				created.emit()
			else:
				message = "NAO FOI POSSIVEL ABRIR A PORTA"
		"back":
			cancelled.emit()
	_refresh()


func _change(step: int) -> void:
	var id := str(items[cursor]["id"])
	if id == "mode":
		mode_index = wrapi(mode_index + step, 0, MODES.size())
	elif id == "level":
		level_index = wrapi(level_index + step, 0, Levels.count())
	elif id == "capacity":
		max_players = clampi(max_players + step, SessionConfig.MIN_PLAYERS, SessionConfig.MAX_PLAYERS)
	_refresh()


func _value(id: String) -> String:
	match id:
		"name": return player_name
		"room": return room_name
		"password": return password
	return ""


func _set_text(id: String, value: String) -> void:
	match id:
		"name": player_name = value
		"room": room_name = value
		"password": password = value
	_refresh()


func _refresh() -> void:
	set_item_value("name", player_name + ("_" if _editing == "name" else ""))
	set_item_value("room", room_name + ("_" if _editing == "room" else ""))
	set_item_value("mode", ["HISTORIA", "INFINITO", "CORRIDA", "SANDBOX"][mode_index])
	set_item_value("level", "%02d" % (level_index + 1))
	set_item_value("capacity", str(max_players))
	set_item_value("password", "*".repeat(password.length()) + ("_" if _editing == "password" else "") if not password.is_empty() else "SEM SENHA")
	queue_redraw()


func draw_header() -> void:
	if not message.is_empty():
		PixelFont.draw_text_centered(self, message, SCREEN.x * 0.5, 52.0, Palette.MAGENTA, 1)
