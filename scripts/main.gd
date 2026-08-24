extends Node2D

## Entry point. Owns the input map, the screen stack and the flow between
## title, room select, gameplay, results and the ending.

const HUD_HEIGHT := 14.0

var _levels: Array = []
var _current := 0
var _busy := false

# Endless run state. `_endless` is what every screen branches on; the rest is
# the running tally shown in the summary once the run ends.
var _endless := false
var _run_seed := 0
var _depth := 0
var _run_time := 0.0
var _run_gems := 0
var _run_deaths := 0

# The room just cleared, held back until the player leaves the results screen.
# Replaying it from there has to not count twice.
var _pending: Dictionary = {}

var _level: Level
var _hud: Hud
var _screen: Node2D
var _pause: PauseMenu
var _transition: Transition


func _ready() -> void:
	randomize()
	_setup_input()

	_levels = Levels.all()

	Audio.sfx_enabled = bool(Save.settings["sfx"])
	Audio.music_enabled = bool(Save.settings["music"])

	_transition = Transition.new()
	add_child(_transition)

	_show_title()

	# The music loop is synthesised sample by sample, so let the title screen
	# draw one frame before that work blocks the main thread.
	await get_tree().process_frame
	Audio.start_music()


func _process(delta: float) -> void:
	Save.add_play_time(delta)

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
	_action("p_dash", [KEY_SHIFT, KEY_C, KEY_J], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_X])
	_action("p_restart", [KEY_R], [JOY_BUTTON_Y])
	_action("p_pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	# Only ever read on a menu screen (title, pause), never in a live room, so
	# reusing the C key p_dash already owns causes no real conflict.
	_action("p_codex", [KEY_C, KEY_TAB], [JOY_BUTTON_LEFT_SHOULDER])


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


func _show_codex() -> void:
	_clear_all()
	var screen := CodexScreen.new()
	screen.cancelled.connect(func(): _go(_show_title))
	_set_screen(screen)


func _show_saves() -> void:
	_clear_all()
	var screen := SavesScreen.new()
	screen.picked.connect(func(_slot: int): _go(_show_title))
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
			_go(_show_play_select)
		"levels":
			_go(_show_select)
		"codex":
			_go(_show_codex)
		"saves":
			_go(_show_saves)
		"options":
			_go(_show_options)
		"quit":
			get_tree().quit()


func _show_play_select() -> void:
	_clear_all()
	var screen := PlaySelectScreen.new()
	screen.chosen.connect(_on_play_chosen)
	screen.cancelled.connect(func(): _go(_show_title))
	_set_screen(screen)


func _on_play_chosen(id: String) -> void:
	match id:
		"story":
			var index := _first_unfinished()
			_go(func(): _start_room(index))
		"endless":
			_go(_start_run)


func _show_options() -> void:
	_clear_all()
	var screen := OptionsScreen.new()
	screen.chosen.connect(_on_options_chosen)
	screen.cancelled.connect(func(): _go(_show_title))
	_set_screen(screen)


## The options screen handles its own toggles; only leaving it reaches here.
func _on_options_chosen(id: String) -> void:
	var screen := _screen as OptionsScreen
	if screen != null and screen.apply(id):
		return
	_go(_show_title)


func _on_room_picked(index: int) -> void:
	_go(func(): _start_room(index))


# ---------------------------------------------------------------- gameplay ---

func _start_room(index: int) -> void:
	_endless = false
	_current = index
	_build_room(index, _levels[index])


# --------------------------------------------------------------- endless ---

## Begin a fresh endless run. One seed decides the whole run, so a death drops
## you back into the same room rather than a new one.
func _start_run() -> void:
	_endless = true
	_run_seed = randi()
	_depth = 0
	_run_time = 0.0
	_run_gems = 0
	_run_deaths = 0
	_pending = {}
	_build_room(_depth, LevelGen.generate(_run_seed, _depth))


func _next_endless_room() -> void:
	_build_room(_depth, LevelGen.generate(_run_seed, _depth))


## Close the run, bank the record and show the summary.
func _end_run() -> void:
	var record := Save.record_endless(_depth, _run_gems)
	_clear_all()

	var screen := EndingScreen.new()
	screen.endless = true
	screen.rooms = _depth
	screen.total_time = _run_time
	screen.total_gems = _run_gems
	screen.deaths = _run_deaths
	screen.new_record = record
	screen.chosen.connect(_on_ending_chosen)
	_set_screen(screen)
	_endless = false


func _build_room(index: int, data: Dictionary) -> void:
	_clear_all()

	_level = Level.new()
	_level.setup(index, data)
	# Endless is the sandbox: it hands over every move from its first room.
	# The story doles them out as the rooms that teach them come open.
	_level.dash_unlocked = _endless or Save.can_dash()
	_level.pound_unlocked = _endless or Save.can_pound()
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
	if _endless:
		_on_endless_room_completed(time, gems, total)
		return

	var record := Save.record_clear(_current, time, gems, _levels.size())
	var best := Save.best_time(_current)
	var deaths := _level.deaths
	await get_tree().create_timer(0.45).timeout
	_go(func(): _show_results(time, best, record, gems, total, deaths))


func _on_endless_room_completed(time: float, gems: int, total: int) -> void:
	_pending = {"time": time, "gems": gems, "deaths": _level.deaths}
	await get_tree().create_timer(0.45).timeout
	_go(func(): _show_endless_results(time, gems, total, int(_pending["deaths"])))


## Fold the finished room into the run total. Called when the player moves on,
## never when they choose to replay it.
func _commit_room() -> void:
	if _pending.is_empty():
		return
	_depth += 1
	_run_time += float(_pending["time"])
	_run_gems += int(_pending["gems"])
	_run_deaths += int(_pending["deaths"])
	_pending = {}


## Between endless rooms: the same panel as a story room, minus the records
## there is nothing to compare against.
func _show_endless_results(time: float, gems: int, total: int, deaths: int) -> void:
	_clear_all()

	var screen := ResultsScreen.new()
	screen.level_name = Lang.tf("endless.room", [_depth + 1])
	screen.time = time
	screen.best = _run_time
	screen.gems = gems
	screen.gems_total = total
	screen.deaths = deaths
	screen.par = 0.0
	screen.best_label = Lang.t("endless.time")
	screen.items = [
		{"id": "continue", "label": Lang.t("results.continue")},
		{"id": "retry", "label": Lang.t("results.retry")},
		{"id": "end_run", "label": Lang.t("results.end_run")},
	]
	screen.chosen.connect(_on_results_chosen)
	_set_screen(screen)


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
		"continue":
			_commit_room()
			_go(_next_endless_room)
		"end_run":
			_commit_room()
			_go(_end_run)
		"retry":
			if _endless:
				# Discard the run so far for this room and play it again.
				_pending = {}
				_go(_next_endless_room)
			else:
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
	match id:
		"levels":
			_go(_show_select)
		"endless":
			_go(_start_run)
		_:
			_go(_show_title)


# ------------------------------------------------------------------ pause ---

func _open_pause() -> void:
	_pause = PauseMenu.new()
	_pause.endless = _endless
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
		"codex":
			var book := CodexScreen.new()
			book.opaque = false
			book.cancelled.connect(func():
				book.queue_free()
				if _pause != null:
					_pause.visible = true)
			if _pause != null:
				_pause.visible = false
			add_child(book)
		"restart":
			_close_pause()
			_restart_room()
		"levels":
			_close_pause()
			_go(_show_select)
		"end_run":
			_close_pause()
			_go(_end_run)
		"title":
			_close_pause()
			if _endless:
				Save.record_endless(_depth, _run_gems)
				_endless = false
			_go(_show_title)
