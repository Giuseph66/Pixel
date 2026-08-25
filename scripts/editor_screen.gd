class_name EditorScreen
extends Node2D

## The room editor.
##
## The room is drawn at 1:1 under the same 14px band the HUD uses in play, so
## what is on screen here is exactly the screen you get when you press play —
## no scrolling, no zoom, no minimap, because a room is one screen by
## definition and the whole game is built on that.
##
## Terrain is baked into an Image the way level.gd bakes it, but incrementally:
## an edit repaints the tile and its four neighbours rather than the whole
## grid, because the bevel on a tile depends on what is next to it and nothing
## else does. Everything that is not terrain is drawn as a sprite on top, every
## frame, which costs nothing at these counts.

signal test_requested
signal closed

const SCREEN := Vector2(480, 270)
const TILE := 8
const BAND := 14.0

const MODE_PAINT := 0
const MODE_PALETTE := 1
const MODE_SETTINGS := 2
const MODE_HELP := 3
const MODE_EXIT := 4

const TOOL_BRUSH := 0
const TOOL_RECT := 1

## Characters the terrain bake owns. Everything else is a sprite over the top.
const BAKED := ["#", "~", ">", "<", "-"]

## Palette geometry. The cells are big enough to hold a tile at double size,
## because the whole point of the tray is telling two similar tiles apart and
## an 8px sprite in a 12px box cannot do that.
const PAL_CELL := 20.0
const PAL_PITCH := 22.0
const PAL_ROW := 26.0
const PAL_LEFT := 78.0          # where the cells start, from the panel edge
const PAL_LABEL := 70.0         # where the group labels end, right-aligned

const REPEAT_DELAY := 0.26
const REPEAT_RATE := 0.035
const UNDO_LIMIT := 60

## Room being edited. Held by reference: main.gd keeps the same dictionary
## across a playtest, so the editor comes back exactly as it was left.
var room: Dictionary = {}
## Where it lives in Sandbox.all(), or -1 for a room that has never been saved.
var store_index := -1

var cursor := Vector2i(4, 26)
var brush := "#"
var tool := TOOL_BRUSH

var _grid: Array = []
var _mode := MODE_PAINT
var _dirty := false
var _time := 0.0

var _terrain_img: Image
var _terrain_tex: ImageTexture

var _undo: Array = []
var _redo: Array = []
var _stroke := false            # a paint stroke is open; one undo step per stroke
var _rect_anchor := Vector2i(-1, -1)

var _repeat := {}               # action -> seconds until the next auto-move
## A key event switched modes this frame, so the polled handlers sit it out.
## Without this, confirming a tile in the palette with space also paints it:
## _unhandled_input closes the popup, and _process, running later in the same
## frame, still sees that same press as "just pressed" and paints with it.
var _guard := false
## Set once the screen has handed control back to main.gd. The transition takes
## a few frames and this node keeps processing through them, so without it a
## second press during the wipe fires the whole handoff twice.
var _done := false
var _toast := ""
var _toast_time := 0.0

# Palette popup
var _pal_group := 0
var _pal_index := 0

# Settings popup
var _set_row := 0
var _name_field := TextField.new()
var _author_field := TextField.new()

const SETTINGS_ROWS := ["name", "author", "par", "intensity", "dash", "pound", "seed"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if room.is_empty():
		room = Sandbox.blank_room()
	_grid = _to_grid(room["rows"])
	_name_field.text = str(room["name"])
	_author_field.text = str(room.get("author", ""))
	_bake_all()
	_snapshot_baseline()


## Restore the cursor, brush and tool after a playtest, so coming back does not
## dump the player at the corner of the room holding the wrong tile.
func state() -> Dictionary:
	return {"cursor": cursor, "brush": brush, "tool": tool, "index": store_index}


func restore(s: Dictionary) -> void:
	cursor = s.get("cursor", cursor)
	brush = str(s.get("brush", brush))
	tool = int(s.get("tool", tool))
	store_index = int(s.get("index", store_index))


# ------------------------------------------------------------------ grid ---

func _to_grid(rows: PackedStringArray) -> Array:
	var g := []
	for y in Levels.ROWS:
		var row := []
		var line: String = rows[y] if y < rows.size() else ""
		for x in Levels.COLS:
			row.append(line[x] if x < line.length() else ".")
		g.append(row)
	return g


func _at(tx: int, ty: int) -> String:
	if tx < 0 or ty < 0 or tx >= Levels.COLS or ty >= Levels.ROWS:
		return "#"
	return _grid[ty][tx]


func _is_solid(tx: int, ty: int) -> bool:
	var ch := _at(tx, ty)
	return ch == "#" or ch == "~" or ch == ">" or ch == "<"


func _commit_rows() -> void:
	room["rows"] = Levels.bake(_grid)


func _find(ch: String) -> Vector2i:
	for ty in Levels.ROWS:
		for tx in Levels.COLS:
			if _grid[ty][tx] == ch:
				return Vector2i(tx, ty)
	return Vector2i(-1, -1)


## Paint one cell. Unique tiles evict the old one first, so there is never a
## room with two spawns to explain to the player.
func _set_tile(tx: int, ty: int, ch: String) -> void:
	if tx < 0 or ty < 0 or tx >= Levels.COLS or ty >= Levels.ROWS:
		return
	if _grid[ty][tx] == ch:
		return

	if TilePalette.is_unique(ch):
		var old := _find(ch)
		if old.x >= 0:
			_grid[old.y][old.x] = "."
			_repaint_around(old.x, old.y)

	_grid[ty][tx] = ch
	_repaint_around(tx, ty)
	_dirty = true


func _fill_rect(a: Vector2i, b: Vector2i, ch: String) -> void:
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var y1 := maxi(a.y, b.y)
	# A unique tile has no meaning as a rectangle: filling with it would place
	# one tile and erase it fifty times over.
	if TilePalette.is_unique(ch):
		_set_tile(x1, y1, ch)
		return
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_set_tile(x, y, ch)


## Flood the connected run of whatever is under the cursor. Carving a cave out
## of a solid block is otherwise a hundred separate clicks.
func _flood(tx: int, ty: int, ch: String) -> void:
	var target := _at(tx, ty)
	if target == ch:
		return
	var queue: Array = [Vector2i(tx, ty)]
	var seen := {}
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		if seen.has(p):
			continue
		seen[p] = true
		if p.x < 0 or p.y < 0 or p.x >= Levels.COLS or p.y >= Levels.ROWS:
			continue
		if _grid[p.y][p.x] != target:
			continue
		_set_tile(p.x, p.y, ch)
		queue.append(Vector2i(p.x + 1, p.y))
		queue.append(Vector2i(p.x - 1, p.y))
		queue.append(Vector2i(p.x, p.y + 1))
		queue.append(Vector2i(p.x, p.y - 1))


# ---------------------------------------------------------------- undo ---

func _snapshot_baseline() -> void:
	_undo.clear()
	_redo.clear()


func _push_undo() -> void:
	_undo.append(Levels.bake(_grid))
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()


func _undo_step() -> void:
	if _undo.is_empty():
		_toast_key("editor.nothing_undo")
		return
	_redo.append(Levels.bake(_grid))
	_grid = _to_grid(_undo.pop_back())
	_bake_all()
	_dirty = true
	Audio.play("menu_back")


func _redo_step() -> void:
	if _redo.is_empty():
		_toast_key("editor.nothing_redo")
		return
	_undo.append(Levels.bake(_grid))
	_grid = _to_grid(_redo.pop_back())
	_bake_all()
	_dirty = true
	Audio.play("menu_select")


# --------------------------------------------------------------- baking ---

func _bake_all() -> void:
	var w := Levels.COLS * TILE
	var h := Levels.ROWS * TILE
	_terrain_img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	_terrain_img.fill(Color(0, 0, 0, 0))
	for ty in Levels.ROWS:
		for tx in Levels.COLS:
			_paint_cell(tx, ty)
	_terrain_tex = ImageTexture.create_from_image(_terrain_img)


## Repaint a cell and its four neighbours: a tile's bevel is decided by what
## touches it, so changing one tile changes at most five drawings.
func _repaint_around(tx: int, ty: int) -> void:
	for p: Vector2i in [Vector2i(tx, ty), Vector2i(tx + 1, ty), Vector2i(tx - 1, ty),
			Vector2i(tx, ty + 1), Vector2i(tx, ty - 1)]:
		if p.x >= 0 and p.y >= 0 and p.x < Levels.COLS and p.y < Levels.ROWS:
			_paint_cell(p.x, p.y)
	if _terrain_tex != null:
		_terrain_tex.update(_terrain_img)


func _paint_cell(tx: int, ty: int) -> void:
	_terrain_img.fill_rect(Rect2i(tx * TILE, ty * TILE, TILE, TILE), Color(0, 0, 0, 0))
	var ch := _at(tx, ty)
	if ch == "#" or ch == ">" or ch == "<":
		PixelArt.paint_tile(_terrain_img, tx, ty, _is_solid(tx, ty - 1),
			_is_solid(tx, ty + 1), _is_solid(tx - 1, ty), _is_solid(tx + 1, ty))
	elif ch == "~":
		PixelArt.paint_ice(_terrain_img, tx, ty, _is_solid(tx, ty - 1),
			_is_solid(tx, ty + 1), _is_solid(tx - 1, ty), _is_solid(tx + 1, ty))
	elif ch == "-":
		PixelArt.paint_platform(_terrain_img, tx, ty)


# ---------------------------------------------------------------- input ---

func _process(delta: float) -> void:
	_time += delta
	_name_field.tick(delta)
	_author_field.tick(delta)
	if _toast_time > 0.0:
		_toast_time = maxf(_toast_time - delta, 0.0)

	# The shortcuts share keys with the movement actions on purpose — S is
	# p_down, Z is p_accept — so a held Ctrl silences the polled ones and
	# CTRL+S saves instead of saving and walking a tile down.
	if _mode == MODE_PAINT and not _guard and not _done \
			and not Input.is_key_pressed(KEY_CTRL):
		_process_paint(delta)
	_guard = false
	queue_redraw()


## Held-direction movement with the same feel a text cursor has: one step, a
## pause, then a stream. Polled through the input map so a gamepad stick works
## for free.
func _repeat_pressed(action: String, delta: float) -> bool:
	if not Input.is_action_pressed(action):
		_repeat.erase(action)
		return false
	if Input.is_action_just_pressed(action):
		_repeat[action] = REPEAT_DELAY
		return true
	# Held since before this screen existed — the press that started it belongs
	# to whatever menu opened the editor, not to the cursor.
	if not _repeat.has(action):
		return false
	var left := float(_repeat[action]) - delta
	if left <= 0.0:
		_repeat[action] = REPEAT_RATE
		return true
	_repeat[action] = left
	return false


func _process_paint(delta: float) -> void:
	var step := Vector2i.ZERO
	if _repeat_pressed("p_left", delta):
		step.x -= 1
	if _repeat_pressed("p_right", delta):
		step.x += 1
	if _repeat_pressed("p_up", delta):
		step.y -= 1
	if _repeat_pressed("p_down", delta):
		step.y += 1
	if step != Vector2i.ZERO:
		cursor.x = clampi(cursor.x + step.x, 0, Levels.COLS - 1)
		cursor.y = clampi(cursor.y + step.y, 0, Levels.ROWS - 1)

	if Input.is_action_just_pressed("p_accept"):
		_begin_stroke()
		_apply_at(cursor, brush)
	elif not Input.is_action_pressed("p_accept"):
		_stroke = false
	elif _stroke and tool == TOOL_BRUSH:
		# Dragging a line only continues a stroke that started here. A button
		# still held from the menu that opened the editor is not a stroke.
		_paint_at(cursor, brush)


func _begin_stroke() -> void:
	if not _stroke:
		_push_undo()
		_stroke = true


## One click, whichever tool is live.
func _apply_at(at: Vector2i, ch: String) -> void:
	if tool == TOOL_RECT:
		if _rect_anchor.x < 0:
			_rect_anchor = at
			Audio.play("menu_move")
			return
		_fill_rect(_rect_anchor, at, ch)
		_rect_anchor = Vector2i(-1, -1)
		Audio.play("menu_select")
		return
	_paint_at(at, ch)


func _paint_at(at: Vector2i, ch: String) -> void:
	var before := _at(at.x, at.y)
	_set_tile(at.x, at.y, ch)
	if before != ch:
		Audio.play("menu_move", 1.4)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var before := _mode
		_key(event as InputEventKey)
		if _mode != before:
			_guard = true
	elif event is InputEventMouseButton:
		_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _mode == MODE_PAINT:
		var at := _mouse_tile()
		if at.x >= 0:
			cursor = at
			if (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
				if tool == TOOL_BRUSH:
					_paint_at(at, brush)
			elif (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_RIGHT:
				_paint_at(at, ".")


func _mouse_tile() -> Vector2i:
	var m := get_local_mouse_position() - Vector2(0, BAND)
	var at := Vector2i(floori(m.x / TILE), floori(m.y / TILE))
	if at.x < 0 or at.y < 0 or at.x >= Levels.COLS or at.y >= Levels.ROWS:
		return Vector2i(-1, -1)
	return at


func _mouse_button(event: InputEventMouseButton) -> void:
	if _mode == MODE_PALETTE:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_palette_click(get_local_mouse_position())
		return
	if _mode != MODE_PAINT:
		return

	var at := _mouse_tile()
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_cycle_brush(-1)
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_cycle_brush(1)
		return
	if at.x < 0:
		return

	cursor = at
	if not event.pressed:
		_stroke = false
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_begin_stroke()
			_apply_at(at, brush)
		MOUSE_BUTTON_RIGHT:
			_begin_stroke()
			_paint_at(at, ".")
		MOUSE_BUTTON_MIDDLE:
			brush = _at(at.x, at.y)
			Audio.play("menu_select")


func _key(event: InputEventKey) -> void:
	match _mode:
		MODE_PALETTE:
			_palette_key(event)
			return
		MODE_SETTINGS:
			_settings_key(event)
			return
		MODE_HELP:
			_mode = MODE_PAINT
			return
		MODE_EXIT:
			_exit_key(event)
			return

	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z:
				_redo_step() if event.shift_pressed else _undo_step()
			KEY_Y:
				_redo_step()
			KEY_S:
				_save(true)
		return

	match event.keycode:
		KEY_TAB, KEY_C:
			_mode = MODE_PALETTE
			_sync_palette_cursor()
			Audio.play("menu_select")
		KEY_X, KEY_DELETE:
			_begin_stroke()
			_paint_at(cursor, ".")
			_stroke = false
		KEY_Q:
			brush = _at(cursor.x, cursor.y)
			Audio.play("menu_select")
		KEY_R:
			tool = TOOL_RECT if tool == TOOL_BRUSH else TOOL_BRUSH
			_rect_anchor = Vector2i(-1, -1)
			_toast_key("editor.tool_rect" if tool == TOOL_RECT else "editor.tool_brush")
		KEY_F:
			_push_undo()
			_flood(cursor.x, cursor.y, brush)
			Audio.play("menu_select")
		KEY_O:
			_mode = MODE_SETTINGS
			_set_row = 0
			Audio.play("menu_select")
		KEY_H, KEY_F1:
			_mode = MODE_HELP
		KEY_P, KEY_ENTER, KEY_KP_ENTER:
			_playtest()
		KEY_ESCAPE:
			if _rect_anchor.x >= 0:
				_rect_anchor = Vector2i(-1, -1)
				return
			_mode = MODE_EXIT


func _cycle_brush(step: int) -> void:
	var list := TilePalette.chars()
	var i := list.find(brush)
	brush = list[wrapi(i + step, 0, list.size())]
	Audio.play("menu_move")


# --------------------------------------------------------------- actions ---

func _playtest() -> void:
	_commit_rows()
	var wrong := Sandbox.problems(room)
	if not Sandbox.is_playable(room):
		_toast_key(wrong[0] if not wrong.is_empty() else "sandbox.err.no_spawn")
		Audio.play("menu_back")
		return
	_save(false)
	_done = true
	test_requested.emit()


## Write the room into the store. A room being edited for the first time is
## appended; after that it is replaced in place.
func _save(loud: bool) -> void:
	_commit_rows()
	room["name"] = Sandbox.clean_name(_name_field.text)
	room["author"] = Sandbox.clean_name(_author_field.text)
	if room["name"].is_empty():
		room["name"] = Lang.t("sandbox.untitled")

	if store_index < 0:
		store_index = Sandbox.add(room)
		if store_index < 0:
			_toast_key("sandbox.err.full")
			return
	else:
		Sandbox.replace(store_index, room)
	_dirty = false
	if loud:
		_toast_key("editor.saved")
		Audio.play("menu_select")


func _toast_key(key: String) -> void:
	_toast = Lang.t(key)
	_toast_time = 2.2


func _exit_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_S:
			_save(false)
			_done = true
			closed.emit()
		KEY_D:
			_done = true
			closed.emit()
		KEY_ESCAPE, KEY_X:
			_mode = MODE_PAINT


# -------------------------------------------------------------- palette ---

func _sync_palette_cursor() -> void:
	var group := TilePalette.group_of(brush)
	for i in TilePalette.GROUPS.size():
		if TilePalette.GROUPS[i]["id"] == group:
			_pal_group = i
			break
	var list := TilePalette.in_group(group)
	for i in list.size():
		if list[i]["char"] == brush:
			_pal_index = i
			break


func _palette_key(event: InputEventKey) -> void:
	var list := TilePalette.in_group(TilePalette.GROUPS[_pal_group]["id"])
	match event.keycode:
		KEY_LEFT, KEY_A:
			_pal_index = wrapi(_pal_index - 1, 0, list.size())
			Audio.play("menu_move")
		KEY_RIGHT, KEY_D:
			_pal_index = wrapi(_pal_index + 1, 0, list.size())
			Audio.play("menu_move")
		KEY_UP, KEY_W:
			_step_group(-1)
		KEY_DOWN, KEY_S:
			_step_group(1)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z:
			brush = list[_pal_index]["char"]
			_mode = MODE_PAINT
			Audio.play("menu_select")
		KEY_ESCAPE, KEY_TAB, KEY_X, KEY_C:
			_mode = MODE_PAINT
			Audio.play("menu_back")


## Moving between drawers keeps the column where it can, instead of snapping
## back to the first tile every time — the drawers are different lengths and
## losing your place on every press makes the tray feel slippery.
func _step_group(step: int) -> void:
	_pal_group = wrapi(_pal_group + step, 0, TilePalette.GROUPS.size())
	var size := TilePalette.in_group(TilePalette.GROUPS[_pal_group]["id"]).size()
	_pal_index = clampi(_pal_index, 0, size - 1)
	Audio.play("menu_move")


func _palette_click(at: Vector2) -> void:
	for g in TilePalette.GROUPS.size():
		var list := TilePalette.in_group(TilePalette.GROUPS[g]["id"])
		for i in list.size():
			if _palette_cell(g, i).has_point(at):
				brush = list[i]["char"]
				_pal_group = g
				_pal_index = i
				_mode = MODE_PAINT
				Audio.play("menu_select")
				return


# -------------------------------------------------------------- settings ---

func _settings_key(event: InputEventKey) -> void:
	var row: String = SETTINGS_ROWS[_set_row]

	# Typing goes to the field the cursor is on, so the arrow keys stay free to
	# move between rows even while a name is half typed.
	if row == "name" and _name_field.handle(event):
		return
	if row == "author" and _author_field.handle(event):
		return

	match event.keycode:
		KEY_UP, KEY_W:
			_set_row = wrapi(_set_row - 1, 0, SETTINGS_ROWS.size())
			Audio.play("menu_move")
		KEY_DOWN, KEY_S:
			_set_row = wrapi(_set_row + 1, 0, SETTINGS_ROWS.size())
			Audio.play("menu_move")
		KEY_LEFT:
			_nudge(row, -1)
		KEY_RIGHT:
			_nudge(row, 1)
		KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER:
			_save(false)
			_mode = MODE_PAINT
			Audio.play("menu_back")


func _nudge(row: String, dir: int) -> void:
	match row:
		"par":
			room["par"] = clampf(float(room["par"]) + dir * 2.0, 0.0, 600.0)
		"intensity":
			room["intensity"] = clampf(float(room["intensity"]) + dir * 0.1, 0.5, 2.5)
		"dash":
			room["dash"] = not bool(room["dash"])
		"pound":
			room["pound"] = not bool(room["pound"])
		"seed":
			room["seed"] = wrapi(int(room["seed"]) + dir, 0, 100000)
		_:
			return
	_dirty = true
	Audio.play("menu_move")


# ----------------------------------------------------------------- draw ---

func _draw() -> void:
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Palette.BG)
	_draw_room()
	_draw_bar()

	match _mode:
		MODE_PAINT:
			_draw_cursor()
		MODE_PALETTE:
			_draw_palette()
		MODE_SETTINGS:
			_draw_settings()
		MODE_HELP:
			_draw_help()
		MODE_EXIT:
			_draw_exit()

	if _toast_time > 0.0:
		_draw_toast()


func _draw_room() -> void:
	var origin := Vector2(0, BAND)
	draw_rect(Rect2(origin, Vector2(Levels.COLS * TILE, Levels.ROWS * TILE)), Palette.BG)
	_draw_grid_dots(origin)
	draw_texture(_terrain_tex, origin)

	_draw_flood(origin)

	for ty in Levels.ROWS:
		for tx in Levels.COLS:
			var ch: String = _grid[ty][tx]
			# Air draws nothing, and terrain is already in the baked image —
			# except the belts, which are ground with a moving band on top.
			if ch == "." or (BAKED.has(ch) and ch != ">" and ch != "<"):
				continue
			_draw_entity(origin, tx, ty, ch)


## A dot every four tiles. Enough to judge a jump against the numbers in the
## README without the grid drowning the room out.
func _draw_grid_dots(origin: Vector2) -> void:
	for ty in range(0, Levels.ROWS, 4):
		for tx in range(0, Levels.COLS, 4):
			draw_rect(Rect2(origin + Vector2(tx * TILE, ty * TILE), Vector2(1, 1)),
				Palette.FRAME)


## The tide, drawn where it actually is: a bright surface line across the whole
## room and the flood under it, not a mark on one tile. 'A' is a water level,
## and a level that looks like a tile is a room built on a wrong idea of it.
func _draw_flood(origin: Vector2) -> void:
	var line := _find("A")
	if line.y < 0:
		return
	var top := origin.y + line.y * TILE
	var width := float(Levels.COLS * TILE)
	var bottom := origin.y + Levels.ROWS * TILE
	draw_rect(Rect2(origin.x, top, width, bottom - top), Color(Palette.MAGENTA_DARK, 0.4))
	draw_rect(Rect2(origin.x, top, width, 2), Palette.MAGENTA)


func _is_air(tx: int, ty: int) -> bool:
	return _at(tx, ty) == "."


func _draw_entity(origin: Vector2, tx: int, ty: int, ch: String) -> void:
	var cell := origin + Vector2(tx * TILE, ty * TILE)

	match ch:
		"A":
			# Already drawn full width, before every other entity.
			return
		"X":
			_draw_door(cell)
			return
		"z", "Z":
			_draw_blade(cell, tx, ty)
			return

	var sprite := str(TilePalette.entry(ch).get("sprite", ""))
	if sprite.is_empty():
		return
	_blit(PixelArt.tex(sprite), cell, ch == "v")

	# Belts and moving slabs are runs of identical tiles, so the marker that
	# says which way one travels goes on the head of the run only. Stamping it
	# on all six tiles of a slab would bury the slab.
	if tx == 0 or _at(tx - 1, ty) != ch:
		_draw_mark(Rect2(cell, Vector2(TILE, TILE)), ch, 1.0)


## One sprite centred in a tile. Turning it over is a half turn, not a mirror:
## that is what Spike does to hang itself from a ceiling, and a vertical flip
## alone put the highlight on the wrong side.
func _blit(tex: Texture2D, cell: Vector2, turned: bool = false,
		alpha: float = 1.0) -> void:
	var size := Vector2(tex.get_width(), tex.get_height())
	var pos := (cell + (Vector2(TILE, TILE) - size) * 0.5).floor()
	var tint := Color(1, 1, 1, alpha)
	if turned:
		draw_texture_rect(tex, Rect2(pos + size, -size), false, tint)
	else:
		draw_texture_rect(tex, Rect2(pos, size), false, tint)


## The exit, at its real size and in its real place. 'X' marks the foot of a
## frame that is twelve pixels wide and sixteen tall, offset half a tile to the
## right — level.gd has always built it that way. Drawing an eight pixel codex
## icon on the marked tile instead was the editor telling a small lie about
## where the door is, which is exactly the lie a room editor must not tell.
func _draw_door(cell: Vector2) -> void:
	# level.gd puts the node at tile_center + (TILE/2, -TILE/2) and centres a
	# 12x16 sprite on it, which lands the frame's left edge two pixels into the
	# marked tile and its top a whole tile above.
	var tex := PixelArt.tex("door")
	var pos := cell + Vector2(TILE - tex.get_width() * 0.5, -TILE)
	draw_texture(tex, pos.floor())


## A retracting spike, with the reach it will have once it rises. The height
## comes from the same call level.gd makes, so changing the room's seed in the
## settings panel moves these on screen — which is the only way to see what
## that number does before playing the room.
func _draw_blade(cell: Vector2, tx: int, ty: int) -> void:
	var air := RetractSpike.air_above(Callable(self, "_is_air"), tx, ty)
	var height := RetractSpike.height_for(int(room.get("seed", 0)), tx, ty, air)

	if height <= 1:
		_blit(PixelArt.tex("spike_up"), cell)
		return

	# Solid where the blade lives, faded over the tiles it only reaches into.
	_blit(PixelArt.tex("spike_base"), cell)
	for i in range(1, height):
		var above := cell - Vector2(0, TILE * i)
		_blit(PixelArt.tex("spike_tip" if i == height - 1 else "spike_shaft"),
			above, false, 0.45)


func _draw_cursor() -> void:
	var origin := Vector2(0, BAND)
	if tool == TOOL_RECT and _rect_anchor.x >= 0:
		var x0 := mini(_rect_anchor.x, cursor.x)
		var y0 := mini(_rect_anchor.y, cursor.y)
		var w := absi(cursor.x - _rect_anchor.x) + 1
		var h := absi(cursor.y - _rect_anchor.y) + 1
		var area := Rect2(origin + Vector2(x0 * TILE, y0 * TILE), Vector2(w * TILE, h * TILE))
		draw_rect(area, Color(Palette.CYAN, 0.18))
		Util.draw_panel(self, area, Color(0, 0, 0, 0), Palette.CYAN)

	var cell := Rect2(origin + Vector2(cursor.x * TILE, cursor.y * TILE),
		Vector2(TILE, TILE))
	var color := Palette.WHITE if fmod(_time, 0.6) < 0.3 else Palette.MAGENTA
	Util.draw_panel(self, cell, Color(0, 0, 0, 0), color)


## The bar is laid out right to left, so the pieces that can be any length —
## the room's name and the brush's name — are fitted to whatever is left over
## rather than drawn on top of the keys hint, which is what used to happen to
## any tile whose name ran long.
func _draw_bar() -> void:
	draw_rect(Rect2(0, 0, SCREEN.x, BAND), Palette.BG)
	draw_rect(Rect2(0, BAND - 1, SCREEN.x, 1), Palette.FRAME)

	var right := SCREEN.x - 4.0
	var hint := Lang.t("editor.hint")
	var hint_size := PixelFont.measure(hint, 1)
	PixelFont.draw_text(self, hint, Vector2(right - hint_size.x, 4), Palette.GREY_DARK, 1)
	right -= hint_size.x + 8.0

	if tool == TOOL_RECT:
		var tag := Lang.t("editor.tag_rect")
		var tag_size := PixelFont.measure(tag, 1)
		PixelFont.draw_text(self, tag, Vector2(right - tag_size.x, 4), Palette.CYAN, 1)
		right -= tag_size.x + 8.0

	# The brush: its own picture plus its name. The picture is what the eye
	# finds, the name is what settles which of two similar tiles this is.
	#
	# Drawn bare rather than in a framed cell. The bar ends one pixel above the
	# room, so a bordered box down here reads as a tile sitting on the ceiling
	# of the level rather than as part of the bar.
	_draw_brush_icon(Vector2(160.0, 3.0))
	PixelFont.draw_text(self, _fit(TilePalette.name_of(brush), right - 176.0),
		Vector2(176, 4), TilePalette.group_color(TilePalette.group_of(brush)), 1)

	PixelFont.draw_text(self, "%02d,%02d" % [cursor.x, cursor.y], Vector2(116, 4),
		Palette.GREY_DARK, 1)

	var title := str(room.get("name", ""))
	if _dirty:
		title += "*"
	PixelFont.draw_text(self, _fit(title, 108.0), Vector2(4, 4), Palette.WHITE, 1)


func _draw_brush_icon(at: Vector2) -> void:
	if brush == ".":
		draw_rect(Rect2(at.x, at.y + 3.0, 8, 2), Palette.GREY_DARK)
		return
	var tex := TilePalette.icon(brush)
	var size := Vector2(tex.get_width(), tex.get_height())
	if brush == "v":
		draw_texture_rect(tex, Rect2(at + size, -size), false)
	else:
		draw_texture(tex, at)
	_draw_mark(Rect2(at, size), brush, 0.0)


## Cut `text` to whatever fits in `width`. The font is fixed pitch, so this is
## division rather than measuring in a loop.
func _fit(text: String, width: float) -> String:
	var per := float(PixelFont.advance(1))
	var room_for := maxi(floori(width / per), 0)
	return text if text.length() <= room_for else text.substr(0, room_for)


## One palette cell: the tile itself at double size over a framed square, so
## the palette and the room never disagree about what a tile looks like. The
## selected cell is tinted with its chapter colour rather than only outlined —
## a one pixel border on a dark panel is easy to lose.
func _draw_swatch(rect: Rect2, ch: String, selected: bool, hovered: bool,
		icon_scale: float = 2.0) -> void:
	var accent := TilePalette.group_color(TilePalette.group_of(ch))
	var border := Palette.FRAME
	if selected:
		border = Palette.WHITE if fmod(_time, 0.7) < 0.35 else accent
	elif hovered:
		border = Palette.GREY_DARK
	Util.draw_panel(self, rect, Color(accent, 0.22) if selected else Palette.BG, border)

	if ch == ".":
		# Air has no picture. A short bar reads as "nothing here" where an
		# empty square would just read as a cell that failed to draw.
		draw_rect(Rect2(rect.position.x + 5.0, rect.position.y + rect.size.y * 0.5 - 1.0,
			rect.size.x - 10.0, 2), Palette.GREY_DARK)
		return

	var tex := TilePalette.icon(ch)
	var size := Vector2(tex.get_width(), tex.get_height()) * icon_scale
	var pos := (rect.position + (rect.size - size) * 0.5).floor()
	if ch == "v":
		# A half turn, the same one Spike makes to hang from a ceiling. Turning
		# it on the vertical axis alone put the lit edge on the wrong side and
		# left the palette disagreeing with the room about the same tile.
		draw_texture_rect(tex, Rect2(pos + size, -size), false)
	else:
		draw_texture_rect(tex, Rect2(pos, size), false)

	_draw_mark(rect, ch, 1.0 if icon_scale < 2.0 else 2.0)


## The motion marker for the tiles that share a sprite, dropped along the
## bottom edge over a dark backing so it stays readable on any tile.
func _draw_mark(rect: Rect2, ch: String, pad: float) -> void:
	var mark := TilePalette.mark_of(ch)
	if mark.is_empty():
		return
	var w := float((mark[0] as String).length())
	var h := float(mark.size())
	var at := Vector2(
		roundf(rect.position.x + (rect.size.x - w) * 0.5),
		roundf(rect.position.y + rect.size.y - h - pad)
	)
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(Palette.OUTLINE, 0.8))
	for y in mark.size():
		var row: String = mark[y]
		for x in row.length():
			if row[x] == "x":
				draw_rect(Rect2(at + Vector2(x, y), Vector2(1, 1)), Palette.WHITE)


func _palette_cell(group: int, i: int) -> Rect2:
	var panel := _palette_panel()
	return Rect2(
		panel.position.x + PAL_LEFT + i * PAL_PITCH,
		panel.position.y + 24.0 + group * PAL_ROW,
		PAL_CELL, PAL_CELL
	)


func _palette_panel() -> Rect2:
	var widest := 0
	for group: Dictionary in TilePalette.GROUPS:
		widest = maxi(widest, TilePalette.in_group(group["id"]).size())
	var width := PAL_LEFT + widest * PAL_PITCH + 10.0
	var height := 24.0 + TilePalette.GROUPS.size() * PAL_ROW + 42.0
	return Rect2(roundf((SCREEN.x - width) * 0.5), roundf((SCREEN.y - height) * 0.5),
		width, height)


func _draw_palette() -> void:
	var dim := Palette.BG
	dim.a = 0.9
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), dim)

	var panel := _palette_panel()
	var cx := panel.position.x + panel.size.x * 0.5
	var mouse := get_local_mouse_position()
	Util.draw_panel(self, panel, Palette.BG_SOFT, Palette.FRAME)

	PixelFont.draw_text_centered(self, Lang.t("editor.palette"), cx,
		panel.position.y + 7.0, Palette.WHITE, 1)
	draw_rect(Rect2(panel.position.x + 8.0, panel.position.y + 19.0,
		panel.size.x - 16.0, 1), Palette.FRAME)

	for g in TilePalette.GROUPS.size():
		var group: Dictionary = TilePalette.GROUPS[g]
		var list := TilePalette.in_group(group["id"])
		var row_y := panel.position.y + 24.0 + g * PAL_ROW

		# Labels are right-aligned against the cells so the tray reads as one
		# column of tiles with a spine of names beside it, not as five lists.
		var label := Lang.t(group["label"])
		var size := PixelFont.measure(label, 1)
		PixelFont.draw_text(self, label,
			Vector2(panel.position.x + PAL_LABEL - size.x, row_y + 7.0),
			group["color"] if g == _pal_group else Palette.GREY_DARK, 1)

		for i in list.size():
			var cell := _palette_cell(g, i)
			_draw_swatch(cell, list[i]["char"], g == _pal_group and i == _pal_index,
				cell.has_point(mouse))

	_draw_palette_footer(panel)


## Name, tile character and the one-line note for whatever the cursor is on.
## The character is worth showing: it is what ends up in the saved file and in
## every table in the docs, so the palette is where you learn to read one.
func _draw_palette_footer(panel: Rect2) -> void:
	var list := TilePalette.in_group(TilePalette.GROUPS[_pal_group]["id"])
	var ch := str(list[_pal_index]["char"])
	var cx := panel.position.x + panel.size.x * 0.5
	var foot := panel.position.y + panel.size.y - 36.0

	draw_rect(Rect2(panel.position.x + 8.0, foot - 6.0, panel.size.x - 16.0, 1),
		Palette.FRAME)

	var name_text := TilePalette.name_of(ch)
	var tag := "[%s]" % ch
	var name_size := PixelFont.measure(name_text, 1)
	var tag_size := PixelFont.measure(tag, 1)
	var total := name_size.x + 6.0 + tag_size.x
	var left := roundf(cx - total * 0.5)
	PixelFont.draw_text(self, name_text, Vector2(left, foot), Palette.WHITE, 1)
	PixelFont.draw_text(self, tag, Vector2(left + name_size.x + 6.0, foot),
		TilePalette.group_color(TilePalette.group_of(ch)), 1)

	PixelFont.draw_text_centered(self, TilePalette.note_of(ch), cx, foot + 11.0,
		Palette.GREY, 1)
	PixelFont.draw_text_centered(self, Lang.t("editor.palette_footer"), cx, foot + 23.0,
		Palette.GREY_DARK, 1)


func _draw_settings() -> void:
	var dim := Palette.BG
	dim.a = 0.92
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), dim)

	var panel := Rect2(90, 40, 300, 190)
	Util.draw_panel(self, panel, Palette.BG_SOFT, Palette.FRAME)
	PixelFont.draw_text_centered(self, Lang.t("editor.settings"),
		panel.position.x + panel.size.x * 0.5, panel.position.y + 8.0, Palette.WHITE, 2)

	for i in SETTINGS_ROWS.size():
		var row: String = SETTINGS_ROWS[i]
		var y := panel.position.y + 40.0 + i * 16.0
		var selected := i == _set_row
		var color := Palette.WHITE if selected else Palette.GREY_DARK
		PixelFont.draw_text(self, Lang.t("editor.field." + row),
			Vector2(panel.position.x + 14.0, y), color, 1)
		PixelFont.draw_text(self, _field_value(row, selected),
			Vector2(panel.position.x + 150.0, y),
			Palette.CYAN if selected else Palette.GREY, 1)
		if selected:
			PixelFont.draw_text(self, ">", Vector2(panel.position.x + 5.0, y),
				Palette.MAGENTA, 1)

	# Whatever is wrong with the room, said plainly and while there is still a
	# panel open to fix it in.
	var wrong := Sandbox.problems(_committed())
	var y := panel.position.y + panel.size.y - 34.0
	if wrong.is_empty():
		PixelFont.draw_text_centered(self, Lang.t("sandbox.ok"),
			panel.position.x + panel.size.x * 0.5, y, Palette.GREEN, 1)
	else:
		PixelFont.draw_text_centered(self, Lang.t(wrong[0]),
			panel.position.x + panel.size.x * 0.5, y, Palette.MAGENTA, 1)

	PixelFont.draw_text_centered(self, Lang.t("editor.settings_footer"),
		panel.position.x + panel.size.x * 0.5, panel.position.y + panel.size.y - 18.0,
		Palette.GREY_DARK, 1)


## The room as it stands right now, for the checks the settings panel runs.
func _committed() -> Dictionary:
	var copy := room.duplicate()
	copy["rows"] = Levels.bake(_grid)
	return copy


func _field_value(row: String, selected: bool) -> String:
	match row:
		"name":
			return _name_field.display() if selected else _name_field.text
		"author":
			var a := _author_field.display() if selected else _author_field.text
			return a if not _author_field.text.is_empty() or selected else "-"
		"par":
			return Lang.t("editor.no_par") if float(room["par"]) <= 0.0 \
				else Util.format_time(float(room["par"]))
		"intensity":
			return "%.1fX" % float(room["intensity"])
		"dash":
			return Lang.t("ui.on") if bool(room["dash"]) else Lang.t("ui.off")
		"pound":
			return Lang.t("ui.on") if bool(room["pound"]) else Lang.t("ui.off")
		"seed":
			return "%05d" % int(room["seed"])
	return ""


func _draw_help() -> void:
	var dim := Palette.BG
	dim.a = 0.95
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), dim)

	var panel := Rect2(50, 24, 380, 222)
	Util.draw_panel(self, panel, Palette.BG_SOFT, Palette.FRAME)
	PixelFont.draw_text_centered(self, Lang.t("editor.help"),
		panel.position.x + panel.size.x * 0.5, panel.position.y + 8.0, Palette.WHITE, 2)

	var y := panel.position.y + 34.0
	for i in 12:
		var key := "editor.help.%d" % i
		var line := Lang.t(key)
		if line == key:
			break
		# "KEY = MEANING", split so the keys line up in a column of their own.
		var parts := line.split("=", true, 1)
		PixelFont.draw_text(self, parts[0].strip_edges(),
			Vector2(panel.position.x + 16.0, y), Palette.CYAN, 1)
		if parts.size() > 1:
			PixelFont.draw_text(self, parts[1].strip_edges(),
				Vector2(panel.position.x + 120.0, y), Palette.GREY, 1)
		y += 13.0

	PixelFont.draw_text_centered(self, Lang.t("editor.help_footer"),
		panel.position.x + panel.size.x * 0.5, panel.position.y + panel.size.y - 16.0,
		Palette.GREY_DARK, 1)


func _draw_exit() -> void:
	var dim := Palette.BG
	dim.a = 0.9
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), dim)
	var panel := Rect2(100, 100, 280, 70)
	Util.draw_panel(self, panel, Palette.BG_SOFT, Palette.FRAME)
	PixelFont.draw_text_centered(self, Lang.t("editor.leave"),
		panel.position.x + panel.size.x * 0.5, panel.position.y + 16.0, Palette.WHITE, 1)
	PixelFont.draw_text_centered(self, Lang.t("editor.leave_footer"),
		panel.position.x + panel.size.x * 0.5, panel.position.y + 42.0, Palette.GREY_DARK, 1)


func _draw_toast() -> void:
	var size := PixelFont.measure(_toast, 1)
	var rect := Rect2(roundf((SCREEN.x - size.x) * 0.5) - 6.0, SCREEN.y - 26.0,
		size.x + 12.0, 14.0)
	Util.draw_panel(self, rect, Palette.BG, Palette.FRAME)
	PixelFont.draw_text_centered(self, _toast, SCREEN.x * 0.5, rect.position.y + 4.0,
		Palette.WHITE, 1)
