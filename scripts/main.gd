extends Node2D

## Entry point. Owns the input map, the screen stack and the flow between
## title, room select, gameplay, results and the ending.

const HUD_HEIGHT := 14.0

var _levels: Array = []
var _current := 0
var _busy := false

var _level: Level
var _hud: Hud
var _screen: Node2D
var _pause: PauseMenu
var _transition: Transition


func _ready() -> void:
	randomize()
	_setup_input()

	_levels = Levels.all()

	Audio.sfx_enabled = bool(Save.data["sfx"])
	Audio.music_enabled = bool(Save.data["music"])

	_transition = Transition.new()
	add_child(_transition)

	_show_title()

	# The music loop is synthesised sample by sample, so let the title screen
	# draw one frame before that work blocks the main thread.
	await get_tree().process_frame
	Audio.start_music()


func _process(_delta: float) -> void:
	if _busy or _level == null or _pause != null or _level.finished:
		return
	if Input.is_action_just_pressed("p_pause"):
		_open_pause()
	elif Input.is_action_just_pressed("p_restart") and not _level.finished:
		_restart_room()


# ------------------------------------------------------------------ input ---

func _setup_input() -> void:
	_action("p_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_action("p_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_action("p_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_action("p_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_action("p_jump", [KEY_SPACE, KEY_Z, KEY_K, KEY_UP, KEY_W], [JOY_BUTTON_A])
	_action("p_accept", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z], [JOY_BUTTON_A])
	_action("p_cancel", [KEY_ESCAPE, KEY_X, KEY_BACKSPACE], [JOY_BUTTON_B])
	_action("p_restart", [KEY_R], [JOY_BUTTON_X])
	_action("p_pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])


func _action(action: String, keys: Array, buttons: Array = [],
		axis: int = -1, axis_value: float = 0.0) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.35)

	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

	for button in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)

	if axis >= 0:
		var event := InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = axis_value
		InputMap.action_add_event(action, event)


# ----------------------------------------------------------------- screens ---

## Wipe out, swap, wipe back in. Guarded so a double press cannot run two
## transitions at once.
func _go(action: Callable) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	await _transition.cover()
	action.call()
	await _transition.reveal()
	_busy = false


func _set_screen(node: Node2D) -> void:
	_clear_screen()
	_screen = node
	add_child(node)


func _clear_screen() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null


func _clear_gameplay() -> void:
	if _hud != null:
		_hud.queue_free()
		_hud = null
	if _level != null:
		_level.queue_free()
		_level = null


func _clear_all() -> void:
	_clear_screen()
	_clear_gameplay()


func _show_title() -> void:
	_clear_all()
	var screen := TitleScreen.new()
	screen.chosen.connect(_on_title_chosen)
	_set_screen(screen)


func _show_select() -> void:
	_clear_all()
	var screen := LevelSelect.new()
	screen.picked.connect(_on_room_picked)
	screen.cancelled.connect(func(): _go(_show_title))
	_set_screen(screen)


func _first_unfinished() -> int:
	for i in _levels.size():
		if Save.is_unlocked(i) and not Save.is_cleared(i):
			return i
	return 0


func _on_title_chosen(id: String) -> void:
	match id:
		"play":
			var index := _first_unfinished()
			_go(func(): _start_room(index))
		"levels":
			_go(_show_select)
		"music":
			var on := not bool(Save.data["music"])
			Save.set_music(on)
			Audio.set_music_enabled(on)
			(_screen as TitleScreen).refresh_audio_labels()
		"sfx":
			var on := not bool(Save.data["sfx"])
			Save.set_sfx(on)
			Audio.set_sfx_enabled(on)
			(_screen as TitleScreen).refresh_audio_labels()
		"language":
			Lang.cycle()
			(_screen as TitleScreen).refresh_labels()
		"quit":
			get_tree().quit()


func _on_room_picked(index: int) -> void:
	_go(func(): _start_room(index))


# ---------------------------------------------------------------- gameplay ---

func _start_room(index: int) -> void:
	_clear_all()
	_current = index
	var data: Dictionary = _levels[index]

	_level = Level.new()
	_level.setup(index, data)
	_level.position = Vector2(0, HUD_HEIGHT)
	_level.completed.connect(_on_room_completed)
	add_child(_level)

	_hud = Hud.new()
	_hud.level = _level
	_hud.level_index = index
	_hud.level_name = data["name"]
	_hud.hint = data["hint"]
	add_child(_hud)


func _restart_room() -> void:
	_level.restart()
	_level.time = 0.0
	if _hud != null:
		_hud.hint = ""


func _on_room_completed(time: float, gems: int, total: int) -> void:
	var record := Save.record_clear(_current, time, gems, _levels.size())
	var best := Save.best_time(_current)
	var deaths := _level.deaths
	await get_tree().create_timer(0.45).timeout
	_go(func(): _show_results(time, best, record, gems, total, deaths))


func _show_results(time: float, best: float, record: bool, gems: int, total: int,
		deaths: int) -> void:
	_clear_all()
	var data: Dictionary = _levels[_current]

	var screen := ResultsScreen.new()
	screen.level_name = data["name"]
	screen.time = time
	screen.best = best
	screen.new_record = record
	screen.gems = gems
	screen.gems_total = total
	screen.deaths = deaths
	screen.par = float(data["par"])

	if _current + 1 < _levels.size():
		screen.items = [
			{"id": "next", "label": Lang.t("results.next")},
			{"id": "retry", "label": Lang.t("results.retry")},
			{"id": "levels", "label": Lang.t("results.rooms")},
		]
	else:
		screen.items = [
			{"id": "ending", "label": Lang.t("results.finish")},
			{"id": "retry", "label": Lang.t("results.retry")},
		]

	screen.chosen.connect(_on_results_chosen)
	_set_screen(screen)


func _on_results_chosen(id: String) -> void:
	match id:
		"next":
			var index := _current + 1
			_go(func(): _start_room(index))
		"retry":
			var index := _current
			_go(func(): _start_room(index))
		"levels":
			_go(_show_select)
		"ending":
			_go(_show_ending)


func _show_ending() -> void:
	_clear_all()
	var total_time := 0.0
	var max_gems := 0
	for i in _levels.size():
		total_time += Save.best_time(i)
		var rows: PackedStringArray = _levels[i]["rows"]
		for row in rows:
			max_gems += row.count("o")

	var screen := EndingScreen.new()
	screen.total_time = total_time
	screen.total_gems = Save.total_gems()
	screen.max_gems = max_gems
	screen.deaths = int(Save.data["total_deaths"])
	screen.chosen.connect(_on_ending_chosen)
	_set_screen(screen)


func _on_ending_chosen(id: String) -> void:
	if id == "levels":
		_go(_show_select)
	else:
		_go(_show_title)


# ------------------------------------------------------------------ pause ---

func _open_pause() -> void:
	_pause = PauseMenu.new()
	_pause.chosen.connect(_on_pause_chosen)
	_pause.cancelled.connect(_close_pause)
	add_child(_pause)
	get_tree().paused = true


func _close_pause() -> void:
	get_tree().paused = false
	if _pause != null:
		_pause.queue_free()
		_pause = null


func _on_pause_chosen(id: String) -> void:
	match id:
		"resume":
			_close_pause()
		"restart":
			_close_pause()
			_restart_room()
		"levels":
			_close_pause()
			_go(_show_select)
		"title":
			_close_pause()
			_go(_show_title)
