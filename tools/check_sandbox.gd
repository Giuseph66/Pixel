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
	failures += await _check_input_guard()
	failures += _check_mirror()
	failures += _check_remix_save()
	failures += _check_count_is_cheap()
	failures += await _check_switch()
	failures += await _check_wind()
	failures += await _check_phase()
	failures += await _check_portal()
	failures += await _check_laser()
	failures += await _check_ferry()
	failures += await _check_charge()
	failures += await _check_pound()
	failures += await _check_modifier_grid()
	failures += _check_wrap()

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


## The sandbox screens read keys two ways at once: overlays are event driven,
## lists are polled through the input map so a gamepad works. Godot dispatches
## events before _process, so a handler that switches into a polled mode leaves
## that mode seeing the very same press as "just pressed" — one tap of space
## walked two steps. The guard is what stops it, and this is what proves the
## guard is armed rather than assuming it.
func _check_input_guard() -> int:
	var bad := 0

	var shelf := SandboxScreen.new()
	add_child(shelf)
	await get_tree().process_frame

	shelf._mode = shelf.MODE_SHARE
	shelf._unhandled_input(_press(KEY_SPACE))
	if shelf._mode != shelf.MODE_LIST:
		bad += _fail("space did not close the share panel")
	if not shelf._guard:
		bad += _fail("leaving the share panel left the list unguarded")
	shelf._process(0.016)
	if shelf._guard:
		bad += _fail("the shelf guard outlived the frame that set it")
	shelf.queue_free()

	var editor := EditorScreen.new()
	editor.room = Sandbox.blank_room()
	add_child(editor)
	await get_tree().process_frame

	editor._mode = editor.MODE_PALETTE
	var before := Levels.bake(editor._grid)
	editor._unhandled_input(_press(KEY_SPACE))
	if editor._mode != editor.MODE_PAINT:
		bad += _fail("space did not confirm the palette choice")
	if not editor._guard:
		bad += _fail("confirming a tile left the canvas unguarded")
	editor._process(0.016)
	# The press that picked the tile must never also paint with it.
	if Levels.bake(editor._grid) != before:
		bad += _fail("picking a tile in the palette painted it as well")
	editor.queue_free()
	await get_tree().process_frame
	return bad


func _press(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	return event


## The share panel prints a filesystem path, which is the one string in the
## game whose length nobody controls — a deep home directory plus a long room
## name used to run off both edges of the panel. Wrapping is what holds it in,
## so the wrapper gets checked rather than trusted.
## Step 20 — the modifier grid replaced a shuffled three-of-nine with all nine
## combos on screen, fixed order, no draw. What has to hold: every combo is
## reachable, CLASSIC sits outside the 3x3 and is reachable from either edge
## of it, a row wraps left/right internally rather than spilling into CLASSIC,
## and the column is remembered across a trip through CLASSIC rather than
## reset to 0 every time.
func _check_modifier_grid() -> int:
	var bad := 0
	if ModifierScreen.VALID_COMBOS.size() != ModifierScreen.COLUMNS * ModifierScreen.ROWS:
		bad += _fail("the grid is %dx%d but there are %d combos"
			% [ModifierScreen.COLUMNS, ModifierScreen.ROWS, ModifierScreen.VALID_COMBOS.size()])

	var m := ModifierScreen.new()
	add_child(m)
	await get_tree().process_frame

	if m._selected != 0 or m._id_for(0) != "":
		bad += _fail("the grid did not start on classic")

	# Right, all the way across a row and one step past, has to land back
	# where it started — a row is a loop, not a line that dumps you off the
	# grid's own edge.
	var start := m._selected
	for i in ModifierScreen.COLUMNS:
		m._move(1, 0)
	if m._selected != start:
		bad += _fail("a full row of right presses did not return to the start")

	# Down from row 0, across every row, has to reach classic on the far side
	# — every combo sits between two trips through classic, never stranded.
	m._selected = 1
	for i in ModifierScreen.ROWS:
		m._move(0, 1)
	if m._selected != 0:
		bad += _fail("moving down through every row did not reach classic")

	# The column survives a trip through classic: right twice from the top
	# row, down into classic, back down into the grid, should land on the
	# same column it left, not column 0.
	m._selected = 1
	m._move(1, 0)
	m._move(1, 0)
	var col_before := (m._selected - 1) % ModifierScreen.COLUMNS
	m._move(0, -1)
	if m._selected != 0:
		bad += _fail("up from the top row did not reach classic")
	m._move(0, 1)
	var col_after := (m._selected - 1) % ModifierScreen.COLUMNS
	if col_after != col_before:
		bad += _fail("classic did not remember the column: left %d, returned on %d"
			% [col_before, col_after])

	# Every combo is reachable and its id round-trips through mods_from_key —
	# what chosen(id) actually hands main.gd.
	var seen := {}
	for combo: Array in ModifierScreen.VALID_COMBOS:
		var key := ModifierScreen.combo_key(combo)
		if seen.has(key):
			bad += _fail("two combos share the key '%s'" % key)
		seen[key] = true
		var back := ModifierScreen.mods_from_key(key)
		var sorted_combo: Array = combo.duplicate()
		sorted_combo.sort()
		if back != sorted_combo:
			bad += _fail("mods_from_key('%s') returned %s, wanted %s" % [key, back, sorted_combo])

	m.queue_free()
	await get_tree().process_frame
	return bad


func _check_wrap() -> int:
	var bad := 0
	var width := 408.0

	var cases := PackedStringArray([
		"/home/somebody-with-a-very-long-name/.local/share/godot/app_userdata/pixel/export/parkour_gelado.pixelroom",
		"/home/jesus/Downloads/parkour_gelado.pixelroom",
		"SHORT",
		"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
	])
	for text: String in cases:
		var lines := PixelFont.wrap(text.to_upper(), width, 1)
		if lines.is_empty():
			bad += _fail("wrapping '%s' produced nothing" % text.substr(0, 20))
			continue
		# Nothing may be dropped: the path has to still be the path.
		if "".join(lines) != text.to_upper():
			bad += _fail("wrapping changed '%s'" % text.substr(0, 20))
		for line: String in lines:
			var w := PixelFont.measure(line, 1).x
			if w > width:
				bad += _fail("a wrapped line is %d px wide, panel holds %d"
					% [int(w), int(width)])

	if PixelFont.wrap("SHORT", width, 1).size() != 1:
		bad += _fail("a string that already fits got wrapped anyway")

	# Downloads has to be somewhere the game can actually write.
	var dir := Sandbox.export_dir()
	if dir.is_empty() or not DirAccess.dir_exists_absolute(dir):
		bad += _fail("the export folder '%s' does not exist" % dir)
	print("check_sandbox: exports go to %s" % dir)

	# Whatever is sitting in those folders right now, read the way the import
	# panel would read it. Informational: what is on this machine is not
	# something a test gets to have an opinion about.
	for entry: Dictionary in Sandbox.drop_files():
		var rooms := Sandbox.read_file(str(entry["path"]))
		print("check_sandbox: importable %s -> %d room(s)" % [entry["label"], rooms.size()])
	return bad


## Step 11. Mirroring shifts 'X' one column left to compensate for the door's
## own rendering offset — see Levels.mirror(). That shift silently corrupts a
## room if the target column was not empty air, so every campaign room gets
## checked here rather than trusted from the one hand-verified example.
func _check_mirror() -> int:
	var bad := 0
	var rooms := Levels.all()

	for room: Dictionary in rooms:
		var id: String = room.get("id", "?")
		var rows: PackedStringArray = room["rows"]
		var mirrored := Levels.mirror(rows)

		if mirrored.size() != Levels.ROWS:
			bad += _fail("mirror('%s') returned %d rows" % [id, mirrored.size()])
			continue
		for row: String in mirrored:
			if row.length() != Levels.COLS:
				bad += _fail("mirror('%s') produced a %d-wide row" % [id, row.length()])
				break

		# Multiset of characters has to survive, except the pairs mirror() is
		# explicitly allowed to swap into each other ('>' <-> '<'). Everything
		# else changing count means the door shift overwrote real terrain.
		var before := _counts(rows)
		var after := _counts(mirrored)
		var pooled := {}
		for ch: String in before:
			pooled[ch] = true
		for ch: String in after:
			pooled[ch] = true
		var seen := {}
		for ch: String in pooled:
			if seen.has(ch):
				continue
			var partner: String = Levels.MIRROR_PAIRS.get(ch, ch)
			seen[ch] = true
			seen[partner] = true
			var before_sum := int(before.get(ch, 0)) + (int(before.get(partner, 0)) if partner != ch else 0)
			var after_sum := int(after.get(ch, 0)) + (int(after.get(partner, 0)) if partner != ch else 0)
			if before_sum != after_sum:
				bad += _fail("mirror('%s') changed how many '%s'/'%s' tiles exist"
					% [id, ch, partner])

		var doors := 0
		for row: String in mirrored:
			doors += row.count("X")
		if doors != 1:
			bad += _fail("mirror('%s') has %d doors, expected 1" % [id, doors])

		var spawns := 0
		for row: String in mirrored:
			spawns += row.count("P")
		if spawns != 1:
			bad += _fail("mirror('%s') has %d spawns, expected 1" % [id, spawns])

		# The door shift is a visual correction, and it used to be applied
		# without asking what the door was standing on: a door built on the
		# last tile of its slab lands one column past the end of that slab
		# once the room is reversed, hanging over the drop it was meant to
		# finish. Counting doors cannot see that — only the tile under it can.
		bad += _check_door_footing(id, mirrored)

	return bad


## Ground directly under the exit, the same rule tools/verify_rooms.py applies
## to the un-mirrored campaign.
func _check_door_footing(id: String, rows: PackedStringArray) -> int:
	for y in rows.size():
		var x := rows[y].find("X")
		if x < 0:
			continue
		var below := "#" if y + 1 >= rows.size() else rows[y + 1][x]
		if below != "#" and below != "-" and below != "~" \
				and below != ">" and below != "<":
			return _fail("mirror('%s') left its door at (%d,%d) standing on '%s'"
				% [id, x, y, below])
	return 0


## Levels.count() is asked for from inside _draw() on three separate screens —
## twice a frame on the level select, once per slot on the saves screen. Answer
## it with all() and each of those calls repaints every room in the game: 80
## rooms measured ~51 ms, which is the whole frame budget several times over and
## is exactly what "the level screen is very slow" turned out to be. This pins
## it to the cached path rather than trusting a comment to keep it there.
func _check_count_is_cheap() -> int:
	var bad := 0
	if Levels.count() != Levels.all().size():
		bad += _fail("Levels.count() disagrees with all().size()")

	Levels.ids()          # the cache is warm in the real game before any screen draws
	var started := Time.get_ticks_usec()
	for i in 200:
		Levels.count()
	var each := float(Time.get_ticks_usec() - started) / 200000.0
	# A cached count is microseconds. Anything approaching a millisecond means
	# it is rebuilding rooms again; a whole frame is 16.6.
	if each > 1.0:
		bad += _fail("Levels.count() costs %.2f ms a call — it is rebuilding rooms" % each)
	return bad


## Step 11 — remix progress. Its four sub-dictionaries live under a "remix"
## key that every remix reader indexes directly, and _read() only ever copies
## keys blank_slot() already declares — so a slot missing the key is not a
## stale field, it is every remix call in the game raising "Invalid access to
## key 'remix'" the moment the mode is opened.
func _check_remix_save() -> int:
	var bad := 0

	var blank := Save.blank_slot()
	if not blank.has("remix"):
		bad += _fail("blank_slot() does not declare a 'remix' key")
	else:
		for field: String in ["cleared", "best_times", "gems", "medals"]:
			if not (blank["remix"] as Dictionary).has(field):
				bad += _fail("a blank slot's remix data has no '%s'" % field)

	# Every reader, against a fresh slot, exactly as the level select calls
	# them for each room it draws.
	var restore := Save.data
	var was_tracking := Save.tracking
	Save.data = Save.blank_slot()
	Save.tracking = true

	if Save.is_cleared_remix(0) or Save.medals_remix(0) != 0 \
			or Save.best_gems_remix(0) != 0 or Save.best_time_remix(0) != 0.0:
		bad += _fail("a fresh slot reports remix progress it never had")

	# Medals are handed out cumulatively, and last_awarded is meant to carry
	# only what this attempt won for the first time — reading the stored set
	# after it has already been written back makes that difference zero, and
	# a first medal never gets its flash on the results screen.
	Save.record_clear_remix(0, 1.0, 1, 1, 0, 100.0)
	if Save.last_awarded != (Save.MEDAL_TIME | Save.MEDAL_GEMS | Save.MEDAL_CLEAN):
		bad += _fail("a first remix clear awarded %d, wanted all three medals"
			% Save.last_awarded)
	if Save.medals_remix(0) != (Save.MEDAL_TIME | Save.MEDAL_GEMS | Save.MEDAL_CLEAN):
		bad += _fail("a first remix clear stored %d medals" % Save.medals_remix(0))

	Save.record_clear_remix(0, 1.0, 1, 1, 0, 100.0)
	if Save.last_awarded != 0:
		bad += _fail("repeating a remix clear re-awarded %d" % Save.last_awarded)

	Save.data = restore
	Save.tracking = was_tracking
	return bad


func _counts(rows: PackedStringArray) -> Dictionary:
	var out := {}
	for row: String in rows:
		for i in row.length():
			var ch := row[i]
			out[ch] = int(out.get(ch, 0)) + 1
	return out


## Step 12. A gate with no switch in the room is a wall with no door — cheap
## to check for every campaign room, and for a sample of generated ones too,
## since the generator has its own path (_switch()) that is supposed to be the
## only source of 'g'/'G' there.
func _check_switch() -> int:
	var bad := 0

	for room: Dictionary in Levels.all():
		var has_gate := false
		var has_switch := false
		for row: String in room["rows"]:
			has_gate = has_gate or row.count("g") > 0 or row.count("G") > 0
			has_switch = has_switch or row.count("i") > 0
		if has_gate and not has_switch:
			bad += _fail("room '%s' has a gate with no switch to open it"
				% str(room.get("id", "?")))

	for depth in [12, 16, 20, 24]:
		var data := LevelGen.generate(4242, depth)
		var rows: PackedStringArray = data["rows"]
		var has_gate := false
		var has_switch := false
		for row: String in rows:
			has_gate = has_gate or row.count("g") > 0 or row.count("G") > 0
			has_switch = has_switch or row.count("i") > 0
		if has_gate and not has_switch:
			bad += _fail("a generated depth-%d room has a gate with no switch" % depth)

	# The mechanism itself: build the actual first switch room, flip it twice,
	# and confirm the gate's collision — not just its sprite — followed along.
	var room: Dictionary = {}
	for entry: Dictionary in Levels.all():
		if entry.get("id", "") == "switch_first":
			room = entry
			break
	if room.is_empty():
		bad += _fail("switch_first is missing from the campaign")
		return bad

	var level := Level.new()
	level.setup(0, room)
	add_child(level)
	await get_tree().process_frame

	# Gates live under Level's private _entities node; walk the tree instead of
	# reaching into a var this test has no business touching directly.
	var gate := _find_gate(level)
	if gate == null:
		bad += _fail("switch_first built with no GateBlock in it")
	else:
		var closed := gate.solid
		level.toggle_switch()
		if gate.solid == closed:
			bad += _fail("toggling the switch did not move the gate")
		level.toggle_switch()
		if gate.solid != closed:
			bad += _fail("two presses did not return the gate to its start")

	level.queue_free()
	await get_tree().process_frame
	return bad


func _find_gate(node: Node) -> GateBlock:
	if node is GateBlock:
		return node
	for child in node.get_children():
		var found := _find_gate(child)
		if found != null:
			return found
	return null


## Step 13. Two things worth checking without eyes on the room: that a run of
## 'u'/'U' becomes exactly one Wind node with the right direction and length,
## and that the push is real — a player inside an upward column has to fall
## slower than one with nothing pushing on it, over the same span of frames.
func _check_wind() -> int:
	var bad := 0

	var g := Levels.blank()
	Levels.rect(g, 0, 27, Levels.COLS, 5, "#")
	Levels.rect(g, 10, 20, 1, 3, "u")
	Levels.rect(g, 20, 15, 4, 1, "U")
	Levels.put(g, 4, 26, "P")
	Levels.put(g, 50, 26, "X")
	var room := Sandbox.normalise({"rows": Levels.bake(g)})

	var level := Level.new()
	level.setup(0, Sandbox.to_level_data(room))
	add_child(level)
	await get_tree().process_frame

	var winds: Array = []
	_collect_winds(level, winds)
	if winds.size() != 2:
		bad += _fail("expected 2 Wind nodes from grouping, found %d" % winds.size())
	else:
		var up := 0
		var left := 0
		for w: Wind in winds:
			if w.direction == Vector2.UP and w.tiles == 3:
				up += 1
			elif w.direction == Vector2.LEFT and w.tiles == 4:
				left += 1
		if up != 1 or left != 1:
			bad += _fail("Wind grouping got a direction or length wrong")
	level.queue_free()
	await get_tree().process_frame

	var free_faller := Player.new()
	free_faller.position = Vector2(200, 50)
	add_child(free_faller)

	var wind := Wind.new()
	wind.setup(Vector2.UP, 4)
	wind.position = Vector2(196, 40)
	add_child(wind)
	var lifted := Player.new()
	lifted.position = Vector2(200, 50)
	add_child(lifted)

	for i in 10:
		await get_tree().physics_frame

	if lifted.velocity.y >= free_faller.velocity.y:
		bad += _fail("a player inside an upward wind fell as fast as one outside it")

	free_faller.queue_free()
	wind.queue_free()
	lifted.queue_free()
	await get_tree().process_frame
	return bad


func _collect_winds(node: Node, out: Array) -> void:
	if node is Wind:
		out.append(node)
	for child in node.get_children():
		_collect_winds(child, out)


## Step 14. Confirms the block actually answers to the same signal the player
## fires, and that clearing the dash makes it solid again without crashing
## the ejection pass on a player who is nowhere near it.
func _check_phase() -> int:
	var bad := 0

	var g := Levels.blank()
	Levels.rect(g, 0, 27, Levels.COLS, 5, "#")
	# One tile, not a whole wall — a wall is deliberately one PhaseBlock per
	# grid cell (matching GateBlock's per-tile shape), so a multi-tile wall
	# would fail this "exactly one" check for a reason that has nothing to do
	# with the toggle this test actually cares about.
	Levels.put(g, 30, 24, "p")
	Levels.put(g, 4, 26, "P")
	Levels.put(g, 54, 26, "X")
	var room := Sandbox.normalise({"rows": Levels.bake(g)})

	var level := Level.new()
	level.setup(0, Sandbox.to_level_data(room))
	add_child(level)
	await get_tree().process_frame

	var blocks: Array = []
	_collect_phase_blocks(level, blocks)
	if blocks.size() != 1:
		bad += _fail("expected 1 PhaseBlock, found %d" % blocks.size())
		level.queue_free()
		await get_tree().process_frame
		return bad

	var block: PhaseBlock = blocks[0]
	if not block.solid:
		bad += _fail("a phase block starts intangible")

	var player := level.get_player()
	level._on_player_dash_changed(true, player)
	if block.solid:
		bad += _fail("the block stayed solid while the player was dashing")
	level._on_player_dash_changed(false, player)
	if not block.solid:
		bad += _fail("the block stayed intangible after the dash ended")

	level.queue_free()
	await get_tree().process_frame
	return bad


func _collect_phase_blocks(node: Node, out: Array) -> void:
	if node is PhaseBlock:
		out.append(node)
	for child in node.get_children():
		_collect_phase_blocks(child, out)


## Step 15. Confirms the pair actually links (Level._discover_contents()
## walks the whole grid before wiring twins, which is easy to get backwards),
## and that stepping into one really does move a player to the other with
## speed kept and heading replaced by the exit's own facing.
func _check_portal() -> int:
	var bad := 0

	var g := Levels.blank()
	Levels.rect(g, 0, 27, Levels.COLS, 5, "#")
	Levels.rect(g, 30, 1, 2, 26, "#")
	Levels.put(g, 29, 26, "q")
	Levels.put(g, 32, 26, "Q")
	Levels.put(g, 4, 26, "P")
	Levels.put(g, 54, 26, "X")
	var room := Sandbox.normalise({"rows": Levels.bake(g)})

	var level := Level.new()
	level.setup(0, Sandbox.to_level_data(room))
	add_child(level)
	await get_tree().process_frame

	var portals: Array = []
	_collect_portals(level, portals)
	if portals.size() != 2:
		bad += _fail("expected 2 Portal nodes, found %d" % portals.size())
	else:
		var a: Portal = portals[0]
		var b: Portal = portals[1]
		if a.twin != b or b.twin != a:
			bad += _fail("the portal pair did not link to each other")

		var player := level.get_player()
		var entry: Portal = a if a.facing == Vector2.LEFT else b
		var exit_portal: Portal = b if entry == a else a
		player.global_position = entry.global_position
		player.velocity = Vector2(160.0, -40.0)

		# Captured the instant the teleport is seen, before this player's own
		# next physics step has a chance to bend the exit's heading back
		# toward gravity and air friction.
		var teleported := false
		var seen_velocity := Vector2.ZERO
		for i in 10:
			await get_tree().physics_frame
			if not teleported and player.global_position.distance_to(exit_portal.global_position) < 16.0:
				teleported = true
				seen_velocity = player.velocity

		if not teleported:
			bad += _fail("entering a portal did not move the player to its twin")
		elif not seen_velocity.normalized().is_equal_approx(exit_portal.facing):
			bad += _fail("the exit did not replace heading with its own facing")

	level.queue_free()
	await get_tree().process_frame

	# Regression: a portal standing on a one-way slab used to fall all the way
	# through to the RIGHT default, because is_solid() alone does not count
	# "-" as ground. portal_fall and portal_gem both stand their exit on one.
	var g2 := Levels.blank()
	Levels.rect(g2, 0, 27, Levels.COLS, 5, "#")
	Levels.rect(g2, 10, 10, 4, 1, "-")
	Levels.put(g2, 4, 26, "P")
	Levels.put(g2, 54, 26, "X")
	var room2 := Sandbox.normalise({"rows": Levels.bake(g2)})
	var level2 := Level.new()
	level2.setup(0, Sandbox.to_level_data(room2))
	add_child(level2)
	await get_tree().process_frame
	if level2._portal_facing(11, 9) != Vector2.UP:
		bad += _fail("a portal standing on a one-way slab did not face up")
	level2.queue_free()
	await get_tree().process_frame
	return bad


func _collect_portals(node: Node, out: Array) -> void:
	if node is Portal:
		out.append(node)
	for child in node.get_children():
		_collect_portals(child, out)


## Step 16. Drives the cycle directly with oversized deltas rather than
## waiting out 2.5 real seconds per assertion, and checks the one rule the
## plan is explicit about: WARN and FIRE never shrink, only the SLEEP between
## them does.
func _check_laser() -> int:
	var bad := 0

	var laser := Laser.new()
	laser.setup(Vector2.RIGHT, Callable(self, "_always_open"))
	add_child(laser)
	await get_tree().process_frame

	if laser._phase != 0:
		bad += _fail("a laser did not start asleep")

	laser._physics_process(Laser.SLEEP + 0.01)
	if laser._phase != 1:
		bad += _fail("a laser did not warn after its sleep elapsed")
	if not laser._area.monitoring == false:
		bad += _fail("a laser's beam can hit something during the warning")

	laser._physics_process(Laser.WARN + 0.01)
	if laser._phase != 2:
		bad += _fail("a laser did not fire after its warning elapsed")
	if not laser._area.monitoring:
		bad += _fail("a firing laser is not actually able to hit anything")

	laser.speed_scale = 4.0
	if not is_equal_approx(laser._sleep_time(), Laser.SLEEP / 4.0):
		bad += _fail("intensity did not shorten the sleep")
	laser.speed_scale = 1.0

	laser.freeze(4.0)
	if laser._phase != 0 or laser._area.monitoring:
		bad += _fail("freezing a mid-fire laser left it live")

	laser.queue_free()
	await get_tree().process_frame

	# Regression: position is always a tile CENTER (tx*8+4), landing
	# _measure()'s tx/ty exactly on a half-integer. roundi() rounds that up,
	# silently measuring from one tile past the emitter — cutting the beam a
	# tile short firing one way, driving it a tile into the wall firing the
	# other way, depending on which side of the half the rounding lands on.
	var reach_laser := Laser.new()
	reach_laser.position = Vector2(10 * 8 + 4, 5 * 8 + 4)
	add_child(reach_laser)
	await get_tree().process_frame
	reach_laser.setup(Vector2.RIGHT, func(nx: int, ny: int) -> bool: return nx == 15 and ny == 5)
	reach_laser._measure()
	if not is_equal_approx(reach_laser._reach, 36.0):
		bad += _fail("a laser firing right measured %s, wanted 36 (a wall 5 tiles away)" % reach_laser._reach)
	reach_laser.setup(Vector2.LEFT, func(nx: int, ny: int) -> bool: return nx == 5 and ny == 5)
	reach_laser._measure()
	if not is_equal_approx(reach_laser._reach, 36.0):
		bad += _fail("a laser firing left measured %s, wanted 36 — likely overshooting into the wall" % reach_laser._reach)
	reach_laser.queue_free()
	await get_tree().process_frame

	# Facing: 'L' only ever reads left/right, 'K' only ever reads up/down — an
	# 'L' boxed in on the vertical axis but open sideways still has to pick a
	# side rather than falling back to firing through the floor.
	var g := Levels.blank()
	Levels.rect(g, 0, 27, Levels.COLS, 5, "#")
	Levels.rect(g, 20, 20, 2, 5, "#")
	Levels.put(g, 4, 26, "P")
	Levels.put(g, 54, 26, "X")
	var room := Sandbox.normalise({"rows": Levels.bake(g)})
	var level := Level.new()
	level.setup(0, Sandbox.to_level_data(room))
	add_child(level)
	await get_tree().process_frame
	if level._laser_facing_h(22, 22) != Vector2.RIGHT:
		bad += _fail("an 'L' beside a left-hand wall did not face right")
	if level._laser_facing_v(22, 26) != Vector2.UP:
		bad += _fail("a 'K' standing on the floor did not face up")
	level.queue_free()
	await get_tree().process_frame

	# Regression: the beam's solid-check used to be is_solid(), which is
	# blind to gates the same way ground AI used to be before it switched to
	# is_wall_or_gate() — a closed gate never blocked the beam.
	var gg := Levels.blank()
	Levels.rect(gg, 0, 27, Levels.COLS, 5, "#")
	Levels.rect(gg, 18, 20, 2, 5, "#")
	Levels.put(gg, 20, 22, "L")
	Levels.put(gg, 30, 22, "G")
	Levels.put(gg, 4, 26, "P")
	Levels.put(gg, 54, 26, "X")
	var groom := Sandbox.normalise({"rows": Levels.bake(gg)})
	var glevel := Level.new()
	glevel.setup(0, Sandbox.to_level_data(groom))
	add_child(glevel)
	await get_tree().process_frame
	var gate_laser: Laser = glevel._lasers[0]
	gate_laser._physics_process(Laser.SLEEP + Laser.WARN + 0.01)
	var expect_reach := (30 - 20 - 1) * 8.0 + 4.0
	if not is_equal_approx(gate_laser._reach, expect_reach):
		bad += _fail("a laser's beam passed through a closed gate (reach %s, wanted %s)" % [gate_laser._reach, expect_reach])
	glevel.queue_free()
	await get_tree().process_frame

	# A beam that crosses a portal tile bends: it re-emerges from the twin
	# heading whichever way that twin faces, same substitution a body gets.
	var pg := Levels.blank()
	Levels.rect(pg, 0, 27, Levels.COLS, 5, "#")
	Levels.rect(pg, 18, 20, 2, 5, "#")
	Levels.put(pg, 20, 22, "L")
	Levels.put(pg, 26, 22, "q")
	Levels.put(pg, 40, 14, "#")
	Levels.put(pg, 40, 15, "Q")
	Levels.put(pg, 40, 20, "#")
	Levels.put(pg, 4, 26, "P")
	Levels.put(pg, 54, 26, "X")
	var proom := Sandbox.normalise({"rows": Levels.bake(pg)})
	var plevel := Level.new()
	plevel.setup(0, Sandbox.to_level_data(proom))
	add_child(plevel)
	await get_tree().process_frame
	var portal_laser: Laser = plevel._lasers[0]
	portal_laser._physics_process(Laser.SLEEP + Laser.WARN + 0.01)
	if portal_laser._segments.size() != 2:
		bad += _fail("a laser through a portal produced %d segment(s), wanted 2"
			% portal_laser._segments.size())
	else:
		var first: Dictionary = portal_laser._segments[0]
		var second: Dictionary = portal_laser._segments[1]
		if not is_equal_approx(float(first["reach"]), 52.0):
			bad += _fail("a laser's first leg into a portal measured %s, wanted 52" % first["reach"])
		if second["dir"] != Vector2.DOWN:
			bad += _fail("a laser did not pick up the exit portal's facing after bending")
		if not (second["pos"] as Vector2).is_equal_approx(Vector2(40 * 8 + 4, 15 * 8 + 4)):
			bad += _fail("a laser's second leg did not start from the exit portal")
		if not is_equal_approx(float(second["reach"]), 36.0):
			bad += _fail("a laser's second leg past a portal measured %s, wanted 36" % second["reach"])
	plevel.queue_free()
	await get_tree().process_frame
	return bad


func _always_open(_tx: int, _ty: int) -> bool:
	return false


## Step 17. A player resting on top has to register as "carrying" through
## the real physics path (get_last_slide_collision(), not an Area2D guess),
## and once the deadline runs out the body has to actually let go and, later,
## clean itself up.
func _check_ferry() -> int:
	var bad := 0

	var ferry := FerryBat.new()
	ferry.position = Vector2(200, 100)
	add_child(ferry)
	await get_tree().process_frame
	ferry._time = 0.0    # deterministic phase, so the drift below is not a coin flip

	var player := Player.new()
	player.position = Vector2(200, 70)          # falls onto it under gravity
	add_child(player)
	ferry.players = [player]           # Level normally wires this up; here it is manual

	var carrying := false
	for i in 40:
		await get_tree().physics_frame
		if ferry._carrying:
			carrying = true
			break
	if not carrying:
		bad += _fail("a player standing on a ferry bat was never marked as carried")

	ferry._carry = 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	if ferry._state != FerryBat.State.DIVE:
		bad += _fail("a ferry bat did not dive once its deadline ran out")
	if ferry.collision_layer != 0:
		bad += _fail("a diving ferry bat is still solid under whoever was riding it")

	# AnimatableBody2D reconciles position with the physics server on its own
	# schedule, so a single oversized delta fed to _physics_process by hand
	# does not stick the way it does for a plain Node2D — real ticks it is,
	# enough of them to clear DIVE_DISTANCE at DIVE_SPEED plus some slack.
	var dive_frames := ceili((FerryBat.DIVE_DISTANCE / FerryBat.DIVE_SPEED) * 60.0) + 10
	for i in dive_frames:
		if not is_instance_valid(ferry):
			break
		await get_tree().physics_frame
	if is_instance_valid(ferry):
		bad += _fail("a ferry bat did not clean itself up after diving clear")

	player.queue_free()
	if is_instance_valid(ferry):
		ferry.queue_free()
	await get_tree().process_frame
	return bad


## Step 18. Exercises _handle_jump() directly with the buffer and coyote
## windows pre-armed, rather than simulating 0.35 real seconds of a player
## standing still to get there — the charge/jump interaction is what this
## checks, not the standing-still detection, which is one plain condition.
func _check_charge() -> int:
	var bad := 0
	var player := Player.new()
	add_child(player)
	await get_tree().process_frame

	player._buffer = 0.1
	player._coyote = 0.1
	player._charge = 0.0
	player._handle_jump({})
	var plain := player.velocity.y

	player.velocity = Vector2.ZERO
	player._buffer = 0.1
	player._coyote = 0.1
	player._charge = Player.CHARGE_TIME
	player._handle_jump({})
	var charged := player.velocity.y

	if not (charged < plain):
		bad += _fail("a fully charged jump was not higher than a plain one")
	if not is_equal_approx(charged, plain * Player.CHARGE_BOOST):
		bad += _fail("a full charge did not apply CHARGE_BOOST exactly")
	if player._charge != 0.0:
		bad += _fail("jumping did not spend the charge")

	player._charge = 0.2
	player._on_land()
	if player._charge != 0.0:
		bad += _fail("landing did not clear an in-progress charge")

	player.queue_free()
	await get_tree().process_frame
	return bad


## The pound fires on down alone, and the landing takes the legs: two seconds
## with no walking and no jumping, dash still live, and a body short enough to
## fit through a one-tile gap without its feet ever leaving the ground line
## everything else in the game measures from.
func _check_pound() -> int:
	var bad := 0
	var player := Player.new()
	add_child(player)
	await get_tree().process_frame

	# Down on its own, with jump never touched.
	player._try_pound({"down": true})
	if player._pound == 0:
		bad += _fail("holding down in the air did not start a pound")
	player._pound = 0
	player._try_pound({"down": false, "jump_pressed": true})
	if player._pound != 0:
		bad += _fail("jump with no down started a pound")

	# Down is now both "pound" and "aim the dash downward". Held together with
	# dash it has to still dash, or the down-dash is gone from the game.
	player._pound = 0
	player._dash = 0.0
	player.has_dash = true
	player._dash_cool = 0.0
	player.velocity = Vector2.ZERO
	player.input_provider = func() -> Dictionary:
		return {"right": false, "left": false, "up": false, "down": true,
			"jump": false, "dash": true, "jump_pressed": false, "jump_released": false}
	player._physics_process(1.0 / 60.0)
	if player._pound != 0:
		bad += _fail("down plus dash started a pound instead of a dash")
	if player._dash <= 0.0:
		bad += _fail("down plus dash did not dash")
	elif player._dash_dir.y <= 0.0:
		bad += _fail("down plus dash did not aim downward")
	player.input_provider = Callable()
	player._dash = 0.0
	player._pound = 0

	# Landing hands out the state, and the box shrinks off the top only.
	var rect := player._shape.shape as RectangleShape2D
	var standing_bottom := player._shape.position.y + rect.size.y * 0.5
	player._pound = 2
	player._land_pound()
	if not player.is_footless():
		bad += _fail("landing a pound did not take the legs")
	if not is_equal_approx(player._footless_left, Player.FOOTLESS_TIME):
		bad += _fail("the footless timer started at %s" % player._footless_left)
	if not is_equal_approx(rect.size.y, Player.FOOTLESS_HEIGHT):
		bad += _fail("a footless body is %s tall, wanted %s"
			% [rect.size.y, Player.FOOTLESS_HEIGHT])
	if rect.size.y >= 8.0:
		bad += _fail("a footless body does not fit through a one-tile gap")
	var footless_bottom := player._shape.position.y + rect.size.y * 0.5
	if not is_equal_approx(footless_bottom, standing_bottom):
		bad += _fail("shrinking moved the feet: bottom went from %s to %s"
			% [standing_bottom, footless_bottom])

	# No walking, and the dash still answers the stick.
	player._recover = 0.0
	player.velocity = Vector2.ZERO
	player.input_provider = func() -> Dictionary:
		return {"right": true, "left": false, "up": false, "down": false,
			"jump": false, "dash": false, "jump_pressed": false, "jump_released": false}
	for i in 10:
		player._physics_process(1.0 / 60.0)
	if absf(player.velocity.x) > 1.0:
		bad += _fail("a footless player walked: vx %s" % player.velocity.x)

	player.velocity = Vector2.ZERO
	player.has_dash = true
	player._dash_cool = 0.0
	player.input_provider = func() -> Dictionary:
		return {"right": false, "left": true, "up": false, "down": false,
			"jump": false, "dash": true, "jump_pressed": false, "jump_released": false}
	player._physics_process(1.0 / 60.0)
	if player._dash <= 0.0:
		bad += _fail("a footless player could not dash")
	elif player._dash_dir.x >= 0.0:
		bad += _fail("a footless dash ignored the direction held")

	# No jumping, with a buffered press and coyote time both wide open.
	player._dash = 0.0
	player._lock = 0.0
	player._recover = 0.0
	player.velocity = Vector2.ZERO
	player._buffer = 0.2
	player._coyote = 0.2
	player.input_provider = func() -> Dictionary:
		return {"right": false, "left": false, "up": false, "down": false,
			"jump": true, "dash": false, "jump_pressed": true, "jump_released": false}
	player._physics_process(1.0 / 60.0)
	if player.velocity.y < 0.0:
		bad += _fail("a footless player jumped: vy %s" % player.velocity.y)

	# The timer running out is not enough on its own — a ceiling one tile up
	# has to keep the legs off, or standing up would embed the body in it.
	player.input_provider = Callable()
	player.surface_at = func(_tx: int, _ty: int) -> String: return "#"
	player._footless_left = 0.0
	player._tick_footless(1.0 / 60.0)
	if not player.is_footless():
		bad += _fail("a footless player stood up into solid rock")

	player.surface_at = func(_tx: int, _ty: int) -> String: return "."
	player._tick_footless(1.0 / 60.0)
	if player.is_footless():
		bad += _fail("the legs never came back with the way clear")
	if not is_equal_approx(rect.size.y, float(Player.HEIGHT)):
		bad += _fail("standing back up left the body %s tall" % rect.size.y)

	# A death resets it outright rather than carrying it into the next try.
	player._enter_footless()
	player.respawn(Vector2(40.0, 40.0))
	if player.is_footless():
		bad += _fail("a respawn kept the legs off")

	player.queue_free()
	await get_tree().process_frame
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
