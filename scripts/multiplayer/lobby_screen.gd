class_name LobbyScreen
extends Menu

const MODES := ["story", "endless", "competitive", "sandbox"]

var message := ""


func _ready() -> void:
	super()
	title = "SALA"
	footer = "TODOS PRONTOS PARA INICIAR"
	allow_cancel = true
	list_top = 164.0
	line_height = 18.0
	Session.roster_changed.connect(_refresh)
	Session.config_changed.connect(_on_config_changed)
	Session.join_failed.connect(_on_error)
	_refresh()


func _exit_tree() -> void:
	if Session.roster_changed.is_connected(_refresh):
		Session.roster_changed.disconnect(_refresh)
	if Session.config_changed.is_connected(_on_config_changed):
		Session.config_changed.disconnect(_on_config_changed)
	if Session.join_failed.is_connected(_on_error):
		Session.join_failed.disconnect(_on_error)


func _handle_input() -> void:
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
		_leave()


func _activate() -> void:
	var id := str(items[cursor]["id"])
	if id == "ready":
		var local: Dictionary = Session.participants.get(Session.local_peer_id(), {})
		Session.set_ready(not bool(local.get("ready", false)))
	elif id == "start":
		if not Session.start_game():
			message = "AGUARDANDO TODOS FICAREM PRONTOS"
	elif id.begins_with("kick_"):
		Session.kick(int(id.trim_prefix("kick_")))
	elif id == "leave":
		_leave()
	_refresh()


func _change(step: int) -> void:
	if not Session.is_host():
		return
	var id := str(items[cursor]["id"])
	if id == "mode":
		var current := MODES.find(str(Session.config.get("mode", "story")))
		var next_mode: String = MODES[wrapi(current + step, 0, MODES.size())]
		var changes := {"mode": next_mode}
		if next_mode == "sandbox" and Session.config.get("room_data", {}).is_empty():
			var rooms := Sandbox.all()
			changes["room_data"] = (rooms[0] if not rooms.is_empty() else Sandbox.blank_room()).duplicate(true)
		Session.update_lobby(changes)
	elif id == "level":
		Session.update_lobby({"level_index": wrapi(int(Session.config.get("level_index", 0)) + step, 0, Levels.count())})
	elif id == "capacity":
		var count := Session.participants.size()
		var capacity := clampi(int(Session.config.get("max_players", 4)) + step,
			maxi(count, SessionConfig.MIN_PLAYERS), Session.capacity_limit())
		Session.update_lobby({"max_players": capacity})
	_refresh()


func _leave() -> void:
	Session.leave()
	cancelled.emit()


func _refresh(_unused: Dictionary = {}) -> void:
	var mode := str(Session.config.get("mode", "story"))
	var level := int(Session.config.get("level_index", 0)) + 1
	var capacity := int(Session.config.get("max_players", 0))
	items = [
		{"id": "ready", "label": "PRONTO", "value": "SIM" if _local_ready() else "NAO"},
	]
	if Session.is_host():
		items.push_front({"id": "capacity", "label": "CAPACIDADE", "value": str(capacity)})
		items.push_front({"id": "level", "label": "SALA", "value": "%02d" % level})
		items.push_front({"id": "mode", "label": "MODO", "value": _mode_label(mode)})
		items.append({"id": "start", "label": "INICIAR"})
		for peer_id: int in Session.participants.keys():
			if peer_id != 1:
				items.append({"id": "kick_%d" % peer_id, "label": "EXPULSAR " + str(Session.participants[peer_id].get("name", "PLAYER"))})
	items.append({"id": "leave", "label": "SAIR"})
	cursor = clampi(cursor, 0, maxi(items.size() - 1, 0))
	queue_redraw()


func _local_ready() -> bool:
	return bool((Session.participants.get(Session.local_peer_id(), {}) as Dictionary).get("ready", false))


func _on_config_changed(_config: Dictionary) -> void:
	_refresh()


func _on_error(_reason: String) -> void:
	message = "CONEXAO ENCERRADA"
	_refresh()


func _mode_label(mode: String) -> String:
	return {"story": "HISTORIA", "endless": "INFINITO", "competitive": "CORRIDA", "sandbox": "SANDBOX"}.get(mode, mode.to_upper())


func draw_header() -> void:
	var code := str(Session.config.get("room_code", "LAN"))
	PixelFont.draw_text_centered(self, "CODIGO LAN: " + code, SCREEN.x * 0.5, 56.0, Palette.CYAN, 1)
	PixelFont.draw_text_centered(self, "%d/%d JOGADORES" % [Session.participants.size(), int(Session.config.get("max_players", 0))], SCREEN.x * 0.5, 70.0, Palette.GREY, 1)
	var y := 88.0
	for peer_id: int in Session.participants.keys():
		var participant: Dictionary = Session.participants[peer_id]
		var marker := "HOST" if peer_id == 1 else ""
		var ready := "PRONTO" if bool(participant.get("ready", false)) else "AGUARDA"
		PixelFont.draw_text_centered(self, "%s %s %s" % [str(participant.get("name", "PLAYER")), marker, ready], SCREEN.x * 0.5, y, Palette.WHITE if peer_id == Session.local_peer_id() else Palette.GREY, 1)
		y += 12.0
	if not message.is_empty():
		PixelFont.draw_text_centered(self, message, SCREEN.x * 0.5, 146.0, Palette.MAGENTA, 1)
