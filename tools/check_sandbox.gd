extends Node

## Smoke test for the sandbox mode, run headless:
##
##   godot --headless res://tools/check_sandbox.tscn
##
## Loads every script so a syntax error anywhere fails the run, then exercises
## the parts that have no other way to be checked without a screen: a blank
## room, the validator, a JSON round trip, a share code round trip and the
## res://rooms scan.

func _ready() -> void:
	_fake_input()
	var failures := 0
	failures += _load_all_scripts()
	failures += _check_room_shape()
	failures += _check_round_trip()
	failures += _check_code()
	failures += _check_palette()
	failures += _check_campaign()
	failures += await _check_screens()
	failures += await _check_play()
	failures += _check_layout()
	failures += _check_copy()

	if failures == 0:
		print("check_sandbox: all good")
	else:
		printerr("check_sandbox: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## The screens poll the input map every frame and main.gd is the thing that
## builds it, so the tool has to declare the same actions or every frame of the
## smoke test drowns in "action doesn't exist".
func _fake_input() -> void:
	for action: String in ["p_left", "p_right", "p_up", "p_down", "p_accept",
			"p_cancel", "p_codex", "p_jump", "p_dash", "p_restart", "p_pause"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.35)


func _fail(message: String) -> int:
	printerr("FAIL: " + message)
	return 1


func _load_all_scripts() -> int:
	var bad := 0
	var da := DirAccess.open("res://scripts")
	for file: String in da.get_files():
		if not file.ends_with(".gd"):
			continue
		var script := load("res://scripts/" + file)
		if script == null:
			bad += _fail("could not load scripts/" + file)
	return bad


func _check_room_shape() -> int:
	var bad := 0
	var room := Sandbox.blank_room()
	if room["rows"].size() != Levels.ROWS:
		bad += _fail("blank room has %d rows" % room["rows"].size())
	for row: String in room["rows"]:
		if row.length() != Levels.COLS:
			bad += _fail("blank room row is %d wide" % row.length())
	if not Sandbox.problems(room).is_empty():
		bad += _fail("blank room is not playable: %s" % str(Sandbox.problems(room)))

	# A room with no door has to be caught, or it can never be finished.
	var broken := Sandbox.normalise(room)
	var rows: PackedStringArray = broken["rows"]
	for i in rows.size():
		rows[i] = rows[i].replace("X", ".")
	broken["rows"] = rows
	if not Sandbox.problems(broken).has("sandbox.err.no_exit"):
		bad += _fail("a room with no exit passed the validator")

	# Short and ragged input is padded rather than rejected.
	var ragged := Sandbox.normalise({"rows": ["###", "#.#"]})
	if ragged["rows"].size() != Levels.ROWS or ragged["rows"][0].length() != Levels.COLS:
		bad += _fail("ragged rows were not padded to the grid")
	return bad


func _check_round_trip() -> int:
	var bad := 0
	var room := Sandbox.blank_room()
	room["name"] = "TEST ROOM"
	# One slime dropped into the grid, so the round trip has something other
	# than the blank room's floor to preserve.
	var painted: PackedStringArray = room["rows"]
	var line := painted[20]
	painted[20] = line.substr(0, 10) + "S" + line.substr(11)
	room["rows"] = painted

	var back := Sandbox.rooms_from_text(Sandbox.room_to_text(room))
	if back.size() != 1:
		return _fail("json round trip returned %d rooms" % back.size())
	if back[0]["rows"] != room["rows"]:
		bad += _fail("json round trip changed the grid")
	if back[0]["name"] != room["name"]:
		bad += _fail("json round trip changed the name")

	var pack := Sandbox.rooms_from_text(Sandbox.pack_to_text([room, room]))
	if pack.size() != 2:
		bad += _fail("pack round trip returned %d rooms" % pack.size())
	return bad


func _check_code() -> int:
	var bad := 0
	var room := Sandbox.blank_room()
	var code := Sandbox.encode(room)
	if not code.begins_with(Sandbox.CODE_PREFIX):
		bad += _fail("share code has no prefix")
	var back := Sandbox.rooms_from_text(code)
	if back.size() != 1 or back[0]["rows"] != room["rows"]:
		bad += _fail("share code did not survive the round trip")
	if not Sandbox.rooms_from_text("PIXEL1.not-base64-at-all").is_empty():
		bad += _fail("a broken share code decoded into something")
	if not Sandbox.rooms_from_text("hello").is_empty():
		bad += _fail("plain text decoded into a room")
	return bad


## Every tile the editor can paint has to be a tile level.gd knows, and every
## tile level.gd knows has to be in the palette — otherwise a mechanic exists
## that no custom room can ever use.
func _check_palette() -> int:
	var bad := 0
	for entry: Dictionary in TilePalette.ENTRIES:
		var ch: String = entry["char"]
		if not TilePalette.KEYS.has(ch):
			bad += _fail("palette tile '%s' has no name key" % ch)
		var sprite: String = entry["sprite"]
		if not sprite.is_empty() and not PixelArt.GRIDS.has(sprite):
			bad += _fail("palette tile '%s' points at a missing sprite '%s'" % [ch, sprite])
	for ch: String in Codex.BY_TILE.keys():
		if not TilePalette.exists(ch):
			bad += _fail("tile '%s' exists in the game but not in the palette" % ch)
	return bad


## Build the two sandbox screens for real and let them run a few frames. The
## headless renderer throws the drawing away, but every _draw() still executes,
## which is the only way to catch a bad index or a missing sprite in code that
## otherwise only runs when someone is looking at it.
func _check_screens() -> int:
	var bad := 0
	var room := Sandbox.blank_room()

	var editor := EditorScreen.new()
	editor.room = room
	editor.store_index = -1
	add_child(editor)
	await get_tree().process_frame

	# Every tile in the palette, each in its own cell so the two unique ones do
	# not evict each other, then a pass with the other tools on top.
	for i in TilePalette.ENTRIES.size():
		editor.brush = TilePalette.ENTRIES[i]["char"]
		editor.cursor = Vector2i(5 + i, 20)
		editor._begin_stroke()
		editor._apply_at(editor.cursor, editor.brush)
		editor._stroke = false
	editor.tool = editor.TOOL_RECT
	editor._apply_at(Vector2i(10, 10), "#")
	editor._apply_at(Vector2i(14, 12), "#")
	editor._flood(30, 5, "~")
	editor._undo_step()
	editor._redo_step()

	for mode in [editor.MODE_PAINT, editor.MODE_PALETTE, editor.MODE_SETTINGS,
			editor.MODE_HELP, editor.MODE_EXIT]:
		editor._mode = mode
		editor.queue_redraw()
		await get_tree().process_frame

	if not Sandbox.problems(editor._committed()).is_empty():
		bad += _fail("the editor lost the spawn or the exit while painting")
	editor.queue_free()

	var shelf := SandboxScreen.new()
	add_child(shelf)
	await get_tree().process_frame
	shelf.queue_redraw()
	await get_tree().process_frame
	shelf.queue_free()
	await get_tree().process_frame
	return bad


## Build a Level out of a sandbox room and run it. This is the claim the whole
## mode rests on — that Level cannot tell a hand-painted room from a shipped
## one — so it is worth checking rather than assuming.
func _check_play() -> int:
	var bad := 0
	var room := Sandbox.blank_room()
	var rows: PackedStringArray = room["rows"]
	# A gem, a slime and a spring, so the entity pass has work to do.
	rows[26] = rows[26].substr(0, 20) + "oSJ" + rows[26].substr(23)
	room["rows"] = rows

	var before := int(Save.data["gems_taken"])
	var deaths_before := int(Save.data["total_deaths"])
	Save.tracking = false

	var level := Level.new()
	level.setup(0, Sandbox.to_level_data(room))
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame

	if level.get_player() == null:
		bad += _fail("the room built without a player")
	if level.gems_total != 1:
		bad += _fail("the room counted %d gems, not 1" % level.gems_total)

	# Nothing a sandbox room does may reach the save file.
	Save.add_gem()
	Save.add_death()
	if int(Save.data["gems_taken"]) != before or int(Save.data["total_deaths"]) != deaths_before:
		bad += _fail("a sandbox room wrote to the save file")
	Save.tracking = true

	level.queue_free()
	await get_tree().process_frame
	return bad


## Nothing on a 480x270 screen has room to spare, and every string in here
## exists three times over. This measures the palette tray and the editor's top
## bar in every language rather than trusting that the longest Portuguese tile
## name happens to fit — which is exactly the bug this catches.
func _check_layout() -> int:
	var bad := 0
	var was := Lang.code

	for code: String in Lang.ORDER:
		Lang.set_lang(code)
		var editor := EditorScreen.new()
		var panel: Rect2 = editor._palette_panel()

		if panel.position.x < 0.0 or panel.position.x + panel.size.x > 480.0:
			bad += _fail("[%s] the palette is wider than the screen" % code)
		if panel.position.y < 0.0 or panel.position.y + panel.size.y > 270.0:
			bad += _fail("[%s] the palette is taller than the screen" % code)

		for g in TilePalette.GROUPS.size():
			var group: Dictionary = TilePalette.GROUPS[g]

			# Group labels are right-aligned into a fixed column.
			var label_w := PixelFont.measure(Lang.t(group["label"]), 1).x
			if label_w > editor.PAL_LABEL - 6.0:
				bad += _fail("[%s] the group label '%s' does not fit its column"
					% [code, Lang.t(group["label"])])

			var list := TilePalette.in_group(group["id"])
			for i in list.size():
				var cell: Rect2 = editor._palette_cell(g, i)
				if cell.position.x + cell.size.x > panel.position.x + panel.size.x - 4.0:
					bad += _fail("[%s] palette cell %d/%d spills out of the panel"
						% [code, g, i])

		# Every line the footer can show has to fit inside the panel.
		for entry: Dictionary in TilePalette.ENTRIES:
			var note := TilePalette.note_of(entry["char"])
			if PixelFont.measure(note, 1).x > panel.size.x - 16.0:
				bad += _fail("[%s] the note for '%s' is wider than the palette"
					% [code, entry["char"]])
		if PixelFont.measure(Lang.t("editor.palette_footer"), 1).x > panel.size.x - 16.0:
			bad += _fail("[%s] the palette footer is wider than the palette" % code)

		bad += _check_bar(editor, code)
		bad += _check_panels(code)
		print("layout[%s]: palette %dx%d at %d,%d" % [code,
			int(panel.size.x), int(panel.size.y),
			int(panel.position.x), int(panel.position.y)])
		editor.free()

	Lang.set_lang(was)
	return bad


## The panels that were sized by eye. Both hold a footer line that runs long in
## Portuguese and Spanish, which is exactly where a hand-picked width breaks.
func _check_panels(code: String) -> int:
	var bad := 0
	var checks := [
		{"width": 300.0, "keys": ["sandbox.new_title", "sandbox.src.blank",
			"sandbox.src.story", "sandbox.src.mine", "sandbox.src_footer"]},
		{"width": 440.0, "keys": ["pick.footer", "pick.story_title", "pick.mine_title"]},
		{"width": 480.0, "keys": ["sandbox.footer", "sandbox.footer2"]},
	]
	for check: Dictionary in checks:
		for key: String in check["keys"]:
			var scale := 2 if key.ends_with("_title") else 1
			var w := PixelFont.measure(Lang.t(key), scale).x
			if w > float(check["width"]) - 16.0:
				bad += _fail("[%s] '%s' is %d px wide, panel holds %d"
					% [code, key, int(w), int(float(check["width"]) - 16.0)])
	return bad


## The top bar puts the room name and the brush name in whatever is left after
## the fixed pieces. This checks the longest tile name in this language still
## has room, with the rectangle tag showing, which is the tightest case.
func _check_bar(editor: EditorScreen, code: String) -> int:
	var right := 480.0 - 4.0
	right -= PixelFont.measure(Lang.t("editor.hint"), 1).x + 8.0
	right -= PixelFont.measure(Lang.t("editor.tag_rect"), 1).x + 8.0

	var longest := ""
	for entry: Dictionary in TilePalette.ENTRIES:
		var name_text := TilePalette.name_of(entry["char"])
		if name_text.length() > longest.length():
			longest = name_text

	var space := right - 176.0
	if editor._fit(longest, space) != longest:
		return _fail("[%s] the tile name '%s' is cut off in the top bar (%d px)"
			% [code, longest, int(space)])
	return 0


## Every campaign room has to survive being copied into the sandbox. This is
## the one direction of the mode that reads data it did not write, so a room
## with a name key that does not resolve, or rows the validator rejects, shows
## up here rather than as an editor full of nothing.
func _check_copy() -> int:
	var bad := 0
	var rooms := Levels.all()
	for i in rooms.size():
		var copy := Sandbox.from_level(rooms[i], i)
		if not Sandbox.is_playable(copy):
			bad += _fail("campaign room %d does not survive being copied" % i)
		if copy["rows"] != rooms[i]["rows"]:
			bad += _fail("copying campaign room %d changed the grid" % i)
		if str(copy["name"]).is_empty():
			bad += _fail("campaign room %d copies with no name" % i)
		if int(copy["seed"]) != i:
			bad += _fail("campaign room %d loses its sky when copied" % i)

	# A copy is a new room, never a second handle on the old one.
	var mine := Sandbox.blank_room()
	var twin := Sandbox.duplicate_room(mine)
	if twin["id"] == mine["id"]:
		bad += _fail("a duplicated room kept the original id")
	if twin["rows"] != mine["rows"]:
		bad += _fail("duplicating a room changed the grid")
	return bad


func _check_campaign() -> int:
	var bad := 0
	var rooms := Levels.all()
	if rooms.size() < Levels.ids().size():
		bad += _fail("the id cache is longer than the room list")
	var seen := {}
	for room: Dictionary in rooms:
		var id: String = room.get("id", "")
		if id.is_empty():
			bad += _fail("a campaign room has no id")
		if seen.has(id):
			bad += _fail("two campaign rooms share the id '%s'" % id)
		seen[id] = true
	print("check_sandbox: %d campaign rooms, %d of them from res://rooms"
		% [rooms.size(), Sandbox.pack_rooms().size()])
	return bad
