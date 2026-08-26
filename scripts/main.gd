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
## Step 11 — same 47 rooms, mirrored and 1.35x faster, own save namespace.
var _remix := false
var _run_seed := 0
var _depth := 0
var _run_time := 0.0
var _run_gems := 0
var _run_deaths := 0
var _run_score := 0
var _run_best_combo := 0
## Step 20 — endless modifiers, chosen once at the picker and applied to every
## room the run generates.
var _mods: Array[String] = []

# The room just cleared, held back until the player leaves the results screen.
# Replaying it from there has to not count twice.
var _pending: Dictionary = {}

# Sandbox state. `_sandbox_room` is held by reference, so the editor, the
# playtest and the results screen are all looking at the same dictionary and a
# tile painted before a test is still there after it.
var _sandbox := false
var _sandbox_room: Dictionary = {}
var _sandbox_index := -1
## True while the running room was launched from the editor rather than from
## the shelf, which is the only difference between "retry" and "back to work".
var _from_editor := false
var _editor_state: Dictionary = {}

var _level: Level
var _hud: Hud
var _screen: Node2D
var _pause: PauseMenu
var _transition: Transition
var _cli_network := false


func _ready() -> void:
	randomize()
	_setup_input()

	_levels = Levels.all()

	Audio.sfx_enabled = bool(Save.settings["sfx"])
	Audio.music_enabled = bool(Save.settings["music"])

	_transition = Transition.new()
	add_child(_transition)
	Session.game_start_requested.connect(_on_network_game_start)
	Session.lobby_requested.connect(_on_network_lobby_requested)
	Session.host_left.connect(_on_network_host_left)

	_show_title()
	_parse_network_args()

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
	_action("p_cancel", [KEY_ESCAPE, KEY_X], [JOY_BUTTON_B])
	_action("p_dash", [KEY_SHIFT, KEY_C, KEY_J], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_X])
	_action("p_restart", [KEY_R], [JOY_BUTTON_Y])
	_action("p_pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_action("p_options", [KEY_O])
	# Only ever read on a menu screen (title, pause), never in a live room, so
	# reusing the C key p_dash already owns causes no real conflict.
	_action("p_codex", [KEY_C, KEY_TAB], [JOY_BUTTON_LEFT_SHOULDER])


func _parse_network_args() -> void:
	var role := ""
	var address := "127.0.0.1"
	var port := SessionManager.DEFAULT_PORT
	var capacity := 4
	var player_name := "PLAYER"
	var mode := "story"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--net-role="):
			role = arg.trim_prefix("--net-role=")
		elif arg.begins_with("--net-address="):
			address = arg.trim_prefix("--net-address=")
		elif arg.begins_with("--net-port="):
			port = int(arg.trim_prefix("--net-port="))
		elif arg.begins_with("--net-capacity="):
			capacity = int(arg.trim_prefix("--net-capacity="))
		elif arg.begins_with("--net-name="):
			player_name = arg.trim_prefix("--net-name=")
		elif arg.begins_with("--net-mode="):
			mode = arg.trim_prefix("--net-mode=")
	if role == "host":
		_cli_network = true
		Session.local_profile = {"name": player_name, "color": 0}
		if Session.host_lan({"mode": mode, "max_players": capacity, "port": port}) == OK:
			_show_lobby()
	elif role == "client":
		_cli_network = true
		Session.state_changed.connect(_on_cli_session_state)
		Session.join_lan(address, port, {"name": player_name, "color": 1})


func _on_cli_session_state(next: int, _reason: String) -> void:
	if _cli_network and next == SessionManager.State.LOBBY:
		_show_lobby()


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
	# Reaching the title always means leaving the current network session. This
	# also protects routes other than pause from leaving an ENet peer alive.
	if Session.is_active():
		Session.leave()
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


func _on_room_picked(index: int, remix: bool) -> void:
	_go(func(): _start_room(index, remix))


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
		"multiplayer":
			_go(_show_multiplayer)
		"levels":
			_go(_show_select)
		"codex":
			_go(_show_codex)
		"saves":
			_go(_show_saves)
		"options":
			_go(_show_options)
		"quit":
			if Session.is_active():
				Session.leave()
			get_tree().quit()


func _show_play_select() -> void:
	_clear_all()
	var screen := PlaySelectScreen.new()
	screen.chosen.connect(_on_play_chosen)
	screen.cancelled.connect(func(): _go(_show_title))
	_set_screen(screen)


func _show_multiplayer() -> void:
	_clear_all()
	var screen := MultiplayerScreen.new()
	screen.chosen.connect(_on_multiplayer_chosen)
	screen.cancelled.connect(func(): _go(_show_title))
	_set_screen(screen)


func _on_multiplayer_chosen(id: String) -> void:
	match id:
		"host":
			_go(_show_host_lobby)
		"join":
			_go(_show_join_lobby)
		_:
			_go(_show_title)


func _show_host_lobby() -> void:
	_clear_all()
	var screen := HostScreen.new()
	screen.created.connect(func(): _go(_show_lobby))
	screen.cancelled.connect(func(): _go(_show_multiplayer))
	_set_screen(screen)


func _show_join_lobby() -> void:
	_clear_all()
	var screen := JoinScreen.new()
	screen.joined.connect(func(): _go(_show_lobby))
	screen.cancelled.connect(func():
		Session.leave()
		_go(_show_multiplayer))
	_set_screen(screen)


func _show_lobby() -> void:
	_clear_all()
	var screen := LobbyScreen.new()
	screen.cancelled.connect(func():
		Session.leave()
		_go(_show_multiplayer))
	_set_screen(screen)


func _on_network_game_start(config: Dictionary) -> void:
	if _busy:
		return
	_go(func(): _start_network_game(config))


func _start_network_game(config: Dictionary) -> void:
	var mode := str(config.get("mode", "story"))
	if mode == "endless":
		_endless = true
		_sandbox = false
		_remix = false
		_run_seed = int(config.get("seed", 0))
		if _run_seed == 0:
			_run_seed = randi()
		_depth = 0
		_run_time = 0.0
		_run_gems = 0
		_run_deaths = 0
		_pending = {}
		_build_room(0, LevelGen.generate(_run_seed, _depth))
	elif mode == "sandbox" and config.get("room_data", {}) is Dictionary \
			and not config["room_data"].is_empty():
		_endless = false
		_sandbox = true
		var received_room: Dictionary = config["room_data"]
		_sandbox_room = Sandbox.normalise(received_room)
		if not Session.room_data_matches(received_room) or not Sandbox.is_playable(_sandbox_room):
			Session.leave()
			_go(_show_title)
			return
		_build_room(0, Sandbox.to_level_data(_sandbox_room))
	else:
		_start_room(clampi(int(config.get("level_index", 0)), 0, _levels.size() - 1))
	if _level != null:
		_level.competitive = mode == "competitive"
	Session.mark_playing()


func _on_network_lobby_requested() -> void:
	if _busy:
		return
	_go(_show_lobby)


func _on_network_host_left() -> void:
	if _busy:
		return
	_go(_show_title)


func _on_play_chosen(id: String) -> void:
	match id:
		"story":
			var index := _first_unfinished()
			_go(func(): _start_room(index))
		"endless":
			_go(_show_modifier_picker)
		"sandbox":
			_go(_show_sandbox)


# ---------------------------------------------------------------- sandbox ---

func _show_sandbox() -> void:
	_clear_all()
	_sandbox = false
	Save.tracking = true
	var screen := SandboxScreen.new()
	screen.play_room.connect(_on_sandbox_play)
	screen.edit_room.connect(_on_sandbox_edit)
	screen.new_room.connect(_on_sandbox_new)
	screen.cancelled.connect(func(): _go(_show_play_select))
	_set_screen(screen)


func _on_sandbox_play(index: int) -> void:
	_sandbox_index = index
	_sandbox_room = Sandbox.all()[index]
	_from_editor = false
	_go(_start_sandbox)


func _on_sandbox_edit(index: int) -> void:
	_sandbox_room = Sandbox.all()[index]
	_sandbox_index = index
	_editor_state = {}
	_go(_show_editor)


## A room that is not on the shelf yet: blank, or copied from a campaign room
## or from another custom one. It is not written to the store until the editor
## saves it, so backing straight out leaves no empty shell behind.
func _on_sandbox_new(room: Dictionary) -> void:
	_sandbox_room = room
	_sandbox_index = -1
	_editor_state = {}
	_go(_show_editor)


func _show_editor() -> void:
	_clear_all()
	_sandbox = false
	Save.tracking = true
	var screen := EditorScreen.new()
	screen.room = _sandbox_room
	screen.store_index = _sandbox_index
	if not _editor_state.is_empty():
		screen.restore(_editor_state)
	screen.test_requested.connect(_on_editor_test)
	screen.closed.connect(func(): _go(_show_sandbox))
	_set_screen(screen)


func _on_editor_test() -> void:
	var editor := _screen as EditorScreen
	if editor != null:
		_editor_state = editor.state()
		_sandbox_index = editor.store_index
	_from_editor = true
	_go(_start_sandbox)


func _start_sandbox() -> void:
	_endless = false
	_sandbox = true
	_remix = false
	_current = _sandbox_index
	_build_room(0, Sandbox.to_level_data(_sandbox_room))


## Finishing a custom room: the time and the gems, and nothing recorded. There
## is no par to beat and no medal to win in a room you wrote yourself.
func _show_sandbox_results(time: float, gems: int, total: int, deaths: int) -> void:
	_clear_all()

	var screen := ResultsScreen.new()
	screen.level_name = str(_sandbox_room.get("name", ""))
	screen.time = time
	screen.best = float(_sandbox_room.get("par", 0.0))
	screen.best_label = Lang.t("sandbox.par")
	screen.gems = gems
	screen.gems_total = total
	screen.deaths = deaths
	screen.par = float(_sandbox_room.get("par", 0.0))

	screen.items = [{"id": "retry", "label": Lang.t("results.retry")}]
	if _from_editor:
		screen.items.push_front({"id": "edit", "label": Lang.t("sandbox.back_edit")})
	else:
		screen.items.append({"id": "edit", "label": Lang.t("sandbox.edit")})
	screen.items.append({"id": "sandbox", "label": Lang.t("sandbox.shelf")})
	screen.chosen.connect(_on_results_chosen)
	_set_screen(screen)


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


# ---------------------------------------------------------------- gameplay ---

func _start_room(index: int, remix: bool = false) -> void:
	_endless = false
	_sandbox = false
	_remix = remix
	_current = index
	var data: Dictionary = (_levels[index] as Dictionary).duplicate()
	if remix:
		# duplicate() is load-bearing: without it this mirrors the shared
		# dictionary in _levels in place, and every campaign room after this
		# one boots up already flipped.
		data["rows"] = Levels.mirror(data["rows"])
		data["intensity"] = 1.35
		data["par"] = float(data.get("par", 0.0)) * 0.8
	_build_room(index, data)


# --------------------------------------------------------------- endless ---

## Step 20 — where a run picks its modifiers, before a single room exists.
func _show_modifier_picker() -> void:
	_clear_all()
	var screen := ModifierScreen.new()
	screen.chosen.connect(_on_modifier_chosen)
	screen.cancelled.connect(func(): _go(_show_play_select))
	_set_screen(screen)


func _on_modifier_chosen(id: String) -> void:
	_go(func(): _start_run(ModifierScreen.mods_from_key(id)))


## Begin a fresh endless run. One seed decides the whole run, so a death drops
## you back into the same room rather than a new one.
func _start_run(mods: Array[String] = []) -> void:
	_endless = true
	_sandbox = false
	_remix = false
	_mods = mods
	_run_seed = randi()
	_depth = 0
	_run_time = 0.0
	_run_gems = 0
	_run_deaths = 0
	_run_score = 0
	_run_best_combo = 0
	_pending = {}
	_build_room(_depth, LevelGen.generate(_run_seed, _depth, _mods))


func _next_endless_room() -> void:
	_build_room(_depth, LevelGen.generate(_run_seed, _depth, _mods))


## Close the run, bank the record and show the summary. A modified run's
## score is scaled up by whatever it made harder — a hard twist with nothing
## to show for it on the scoreboard is only punishment, not a real choice.
func _end_run() -> void:
	var mods_key := ModifierScreen.combo_key(_mods)
	var scaled_score := int(round(float(_run_score) * ModifierScreen.score_multiplier(_mods)))
	var record := Save.record_endless(_depth, _run_gems, mods_key)
	Save.record_endless_score(scaled_score, _run_best_combo)
	_clear_all()

	var screen := EndingScreen.new()
	screen.endless = true
	screen.rooms = _depth
	screen.total_time = _run_time
	screen.total_gems = _run_gems
	screen.deaths = _run_deaths
	screen.score = scaled_score
	screen.new_record = record
	screen.chosen.connect(_on_ending_chosen)
	_set_screen(screen)
	_endless = false
	_mods = []


func _build_room(index: int, data: Dictionary) -> void:
	_clear_all()

	# Nothing a custom room does may reach the save file — see Save.tracking.
	Save.tracking = not _sandbox and not Session.is_active()

	_level = Level.new()
	_level.setup(index, data)
	# Endless hands over every move from its first room. The story doles them
	# out as the rooms that teach them come open. A custom room says so itself,
	# which is how you build one that is about wall jumps and nothing else.
	if _sandbox:
		_level.dash_unlocked = bool(_sandbox_room.get("dash", true))
		_level.pound_unlocked = bool(_sandbox_room.get("pound", true))
	else:
		_level.dash_unlocked = Session.is_active() or _endless or _remix or Save.can_dash()
		_level.pound_unlocked = Session.is_active() or _endless or _remix or Save.can_pound()
	# Step 20 — endless modifiers. "brittle" needs nothing here: LevelGen
	# already baked it into data["rows"] before this room existed.
	_level.player_speed_scale = 1.2 if _endless and _mods.has("rush") else 1.0
	_level.player_gravity_scale = 1.15 if _endless and _mods.has("heavy") else 1.0
	_level.dark = _endless and _mods.has("dark")
	_level.position = Vector2(0, HUD_HEIGHT)
	_level.completed.connect(_on_room_completed)
	add_child(_level)

	_hud = Hud.new()
	_hud.level = _level
	_hud.level_index = index
	_hud.level_name = data["name"]
	_hud.hint = data["hint"]
	_hud.show_score = _endless
	add_child(_hud)


## Restarting on purpose is a fresh attempt, clock and all — including the
## death count, which is what the clean-run medal is judged on. Dying and
## respawning is not: that is the same attempt, and it already cost you.
func _restart_room() -> void:
	if Session.is_active():
		return
	_level.restart()
	_level.time = 0.0
	_level.deaths = 0
	if _hud != null:
		_hud.hint = ""


func _on_room_completed(time: float, gems: int, total: int, score: int, best_combo: int) -> void:
	if Session.is_active():
		await get_tree().create_timer(0.45).timeout
		if Session.is_host():
			var next_level := _current + 1
			if str(Session.config.get("mode", "")) == "story" and next_level < _levels.size():
				Session.advance_story(next_level)
			else:
				Session.return_to_lobby()
		return
	if _sandbox:
		var deaths := _level.deaths
		await get_tree().create_timer(0.45).timeout
		_go(func(): _show_sandbox_results(time, gems, total, deaths))
		return
	if _endless:
		_on_endless_room_completed(time, gems, total, score, best_combo)
		return

	var current_par := float(_levels[_current].get("par", 0.0)) * (0.8 if _remix else 1.0)
	var record: bool
	var best: float
	var held: int
	if _remix:
		record = Save.record_clear_remix(_current, time, gems, total, _level.deaths, current_par)
		best = Save.best_time_remix(_current)
		held = Save.medals_remix(_current)
	else:
		record = Save.record_clear(_current, time, gems, _levels.size(),
			total, _level.deaths, current_par)
		best = Save.best_time(_current)
		held = Save.medals(_current)
	var deaths := _level.deaths
	await get_tree().create_timer(0.45).timeout
	var earned := Save.last_awarded
	_go(func(): _show_results(time, best, record, gems, total, deaths, held, earned))


func _on_endless_room_completed(time: float, gems: int, total: int, score: int,
		best_combo: int) -> void:
	_pending = {"time": time, "gems": gems, "deaths": _level.deaths,
		"score": score, "best_combo": best_combo}
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
	_run_score += int(_pending.get("score", 0))
	_run_best_combo = maxi(_run_best_combo, int(_pending.get("best_combo", 0)))
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
		deaths: int, medals: int = 0, new_medals: int = 0) -> void:
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
	screen.par = float(data["par"]) * (0.8 if _remix else 1.0)
	screen.medals = medals
	screen.new_medals = new_medals
	if _remix:
		screen.best_label = Lang.t("remix.best")

	if _current + 1 < _levels.size():
		screen.items = [
			{"id": "next", "label": Lang.t("results.next")},
			{"id": "retry", "label": Lang.t("results.retry")},
			{"id": "levels", "label": Lang.t("results.rooms")},
		]
	elif _remix:
		# The remix has no ending ceremony of its own: the last room just
		# loops back to picking one, same as any room in the middle of it.
		screen.items = [
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
			var remix := _remix
			_go(func(): _start_room(index, remix))
		"continue":
			_commit_room()
			_go(_next_endless_room)
		"end_run":
			_commit_room()
			_go(_end_run)
		"edit":
			_go(_show_editor)
		"sandbox":
			_go(_show_sandbox)
		"retry":
			if _sandbox:
				_go(_start_sandbox)
			elif _endless:
				# Discard the run so far for this room and play it again.
				_pending = {}
				_go(_next_endless_room)
			else:
				var index := _current
				var remix := _remix
				_go(func(): _start_room(index, remix))
		"levels":
			_remix = false
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
	_pause.sandbox = _sandbox
	_pause.networked = Session.is_active()
	_pause.network_host = Session.is_host()
	_pause.chosen.connect(_on_pause_chosen)
	_pause.cancelled.connect(_close_pause)
	add_child(_pause)
	get_tree().paused = true


func _close_pause() -> void:
	get_tree().paused = false
	if _pause != null:
		_pause.queue_free()
		_pause = null


func _suspend_pause_for_overlay() -> void:
	if _pause == null:
		return
	# The overlay has its own input loop. Leaving the pause menu active here
	# lets the same Escape/back press close both screens and drop the player
	# out of the running match.
	_pause.visible = false
	_pause.set_process(false)


func _resume_pause_after_overlay() -> void:
	if _pause == null or not is_instance_valid(_pause):
		return
	_pause.visible = true
	_pause.set_process(true)


func _on_pause_chosen(id: String) -> void:
	match id:
		"resume":
			_close_pause()
		"codex":
			var book := CodexScreen.new()
			book.opaque = false
			book.cancelled.connect(func():
				book.queue_free()
				_resume_pause_after_overlay())
			_suspend_pause_for_overlay()
			add_child(book)
		"options":
			var options := OptionsScreen.new()
			options.opaque = false
			options.chosen.connect(func(id: String):
				if options.apply(id):
					return
				options.queue_free()
				_resume_pause_after_overlay())
			options.cancelled.connect(func():
				options.queue_free()
				_resume_pause_after_overlay())
			_suspend_pause_for_overlay()
			add_child(options)
		"restart":
			_close_pause()
			_restart_room()
		"levels":
			_close_pause()
			# A network room is selected only by the host's synchronized lobby.
			if Session.is_active():
				if Session.is_host():
					Session.return_to_lobby()
			else:
				_go(_show_select)
		"lobby":
			_close_pause()
			if Session.is_host():
				Session.return_to_lobby()
		"leave_server":
			_close_pause()
			Session.leave()
			_sandbox = false
			_endless = false
			Save.tracking = true
			_go(_show_title)
		"edit":
			_close_pause()
			_go(_show_editor)
		"sandbox":
			_close_pause()
			_go(_show_sandbox)
		"end_run":
			_close_pause()
			_go(_end_run)
		"title":
			_close_pause()
			_sandbox = false
			Save.tracking = true
			if _endless:
				Save.record_endless(_depth, _run_gems, ModifierScreen.combo_key(_mods))
				_endless = false
				_mods = []
			_go(_show_title)


func _exit_tree() -> void:
	# Closing the window/application releases the socket and removes this peer
	# from the host roster instead of relying on a later timeout.
	if Session.is_active():
		Session.leave()
