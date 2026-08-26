class_name SandboxScreen
extends Node2D

## The shelf of rooms the player made.
##
## Cards with a real preview rather than a list of names: a room is a picture,
## and after a dozen of them the names all start to sound the same. The first
## card is always the empty one that makes a new room, so "how do I start" has
## the same answer as "what is this screen".

signal edit_room(index: int)
## A room that is not on the shelf yet — blank, or copied from somewhere. It
## stays unsaved until the editor writes it, so backing out of a copy you did
## not want leaves nothing behind.
signal new_room(room: Dictionary)
signal cancelled

const SCREEN := Vector2(480, 270)
const CARD := Vector2(132, 90)
const GAP := Vector2(9, 8)
const ORIGIN := Vector2(30, 42)
const COLUMNS := 3
const VISIBLE_ROWS := 2

const MODE_LIST := 0
const MODE_DELETE := 1
const MODE_IMPORT := 2
const MODE_SHARE := 3
const MODE_SOURCE := 4
const MODE_PICK := 5

## Rows of names visible in the copy picker at once.
const PICK_ROWS := 12
const PICK_LINE := 12.0

var cursor := 0
var _scroll := 0
var _mode := MODE_LIST
var _time := 0.0

## [{text, accent}] — accent marks the lines that are the path itself, which
## the panel colours apart from the sentences around them.
var _share_lines: Array = []
var _import_items: Array = []
var _import_cursor := 0
var _toast := ""
var _toast_time := 0.0

## A key event switched modes this frame, so the polled handlers sit it out.
##
## This screen reads keys two ways: the overlays are event driven, the lists
## are polled through the input map so a gamepad works. Godot dispatches events
## before _process, so one press of space used to walk two steps at once —
## confirm the delete, and then, in the same frame, the list underneath saw
## that same press as "just pressed" and opened whatever the cursor was on.
var _guard := false
## Set once the screen has handed control back to main.gd. The wipe takes a few
## frames and this node keeps processing through them.
var _done := false

# Where a new room comes from.
var _source_cursor := 0
var _source_items: Array = []

# The copy picker: a list of names on the left, one big preview on the right.
# A grid of cards cannot hold forty-seven campaign rooms without turning into
# eight pages of scrolling.
var _pick_rooms: Array = []     # [{name, rows, par, room}]
var _pick_cursor := 0
var _pick_scroll := 0
var _pick_title := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sandbox.all()


## Card 0 is NEW; every card after it is a room.
func _count() -> int:
	return Sandbox.all().size() + 1


func _room_index() -> int:
	return cursor - 1


func _process(delta: float) -> void:
	_time += delta
	if _toast_time > 0.0:
		_toast_time = maxf(_toast_time - delta, 0.0)
	if not _guard and not _done:
		match _mode:
			MODE_LIST:
				_handle_list()
			MODE_PICK:
				_handle_pick()
	_guard = false
	queue_redraw()


func _handle_list() -> void:
	var total := _count()
	if Input.is_action_just_pressed("p_right"):
		cursor = wrapi(cursor + 1, 0, total)
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_left"):
		cursor = wrapi(cursor - 1, 0, total)
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_down"):
		cursor = mini(cursor + COLUMNS, total - 1)
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_up"):
		cursor = maxi(cursor - COLUMNS, 0)
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_accept"):
		_accept()


## Picking a room from the shelf opens it in the editor, never straight into
## play — the editor's own P/Enter is the one place "play this" lives now,
## so getting there is never more than one extra key from here.
func _accept() -> void:
	Audio.play("menu_select")
	if cursor == 0:
		_open_source()
		return
	_done = true
	edit_room.emit(_room_index())


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	var before := _mode
	_dispatch(key)
	if _mode != before:
		_guard = true


func _dispatch(key: InputEventKey) -> void:
	match _mode:
		MODE_DELETE:
			_delete_key(key)
		MODE_IMPORT:
			_import_key(key)
		MODE_SHARE:
			if key.keycode == KEY_ESCAPE or key.keycode == KEY_SPACE:
				_mode = MODE_LIST
		MODE_SOURCE:
			_source_key(key)
		MODE_PICK:
			if key.keycode == KEY_ESCAPE or key.keycode == KEY_X:
				_mode = MODE_SOURCE
				Audio.play("menu_back")
		_:
			_list_key(key)


func _list_key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_E:
			if cursor > 0:
				Audio.play("menu_select")
				_done = true
				edit_room.emit(_room_index())
		KEY_C:
			if cursor > 0:
				var copy := Sandbox.duplicate_room(Sandbox.all()[_room_index()])
				if Sandbox.add(copy) < 0:
					_toast_key("sandbox.err.full")
				else:
					cursor = Sandbox.all().size()
					_toast_key("sandbox.duplicated")
					Audio.play("menu_select")
		KEY_R, KEY_DELETE:
			if cursor > 0:
				_mode = MODE_DELETE
		KEY_X:
			# A and D are the movement actions on this screen, so the second
			# export lives on SHIFT+X rather than on its own letter.
			if key.shift_pressed:
				_share_all()
			elif cursor > 0:
				_share(Sandbox.all()[_room_index()])
		KEY_I:
			_open_import()
		KEY_ESCAPE, KEY_BACKSPACE:
			Audio.play("menu_back")
			_done = true
			cancelled.emit()


# --------------------------------------------------------- new room ---

## Where a new room starts. Copying is not a shortcut here so much as the way
## most rooms actually get made: take one that already works, gut the middle,
## and the parts that were never the point — a sealed border, a floor, a spawn
## that is not in a wall — are already right.
func _open_source() -> void:
	_source_items = [{"id": "blank", "label": Lang.t("sandbox.src.blank")}]
	if Levels.count() > 0:
		_source_items.append({"id": "story", "label": Lang.t("sandbox.src.story")})
	if not Sandbox.all().is_empty():
		_source_items.append({"id": "mine", "label": Lang.t("sandbox.src.mine")})
	_source_cursor = 0
	_mode = MODE_SOURCE


func _source_key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_UP, KEY_W:
			_source_cursor = wrapi(_source_cursor - 1, 0, _source_items.size())
			Audio.play("menu_move")
		KEY_DOWN, KEY_S:
			_source_cursor = wrapi(_source_cursor + 1, 0, _source_items.size())
			Audio.play("menu_move")
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z:
			_choose_source()
		KEY_ESCAPE, KEY_X:
			_mode = MODE_LIST
			Audio.play("menu_back")


func _choose_source() -> void:
	Audio.play("menu_select")
	match str(_source_items[_source_cursor]["id"]):
		"blank":
			_done = true
			new_room.emit(Sandbox.blank_room())
		"story":
			_open_pick(_campaign_entries(), Lang.t("pick.story_title"))
		"mine":
			_open_pick(_mine_entries(), Lang.t("pick.mine_title"))


## Campaign rooms, with their names resolved out of the translation table so
## the list reads as room names rather than as keys.
func _campaign_entries() -> Array:
	var out: Array = []
	var rooms := Levels.all()
	for i in rooms.size():
		var data: Dictionary = rooms[i]
		out.append({
			"name": Lang.t(str(data.get("name", ""))),
			"rows": data["rows"],
			"par": float(data.get("par", 0.0)),
			"room": Sandbox.from_level(data, i),
		})
	return out


func _mine_entries() -> Array:
	var out: Array = []
	for room: Dictionary in Sandbox.all():
		out.append({
			"name": str(room["name"]),
			"rows": room["rows"],
			"par": float(room["par"]),
			"room": Sandbox.duplicate_room(room),
		})
	return out


func _open_pick(entries: Array, title: String) -> void:
	_pick_rooms = entries
	_pick_title = title
	_pick_cursor = 0
	_pick_scroll = 0
	_mode = MODE_PICK


func _handle_pick() -> void:
	if _pick_rooms.is_empty():
		return
	var total := _pick_rooms.size()
	if Input.is_action_just_pressed("p_down"):
		_pick_cursor = wrapi(_pick_cursor + 1, 0, total)
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_up"):
		_pick_cursor = wrapi(_pick_cursor - 1, 0, total)
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_right"):
		_pick_cursor = mini(_pick_cursor + PICK_ROWS, total - 1)
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_left"):
		_pick_cursor = maxi(_pick_cursor - PICK_ROWS, 0)
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_accept"):
		Audio.play("menu_select")
		_done = true
		new_room.emit((_pick_rooms[_pick_cursor] as Dictionary)["room"])

	_pick_scroll = clampi(_pick_scroll, _pick_cursor - PICK_ROWS + 1, _pick_cursor)
	_pick_scroll = clampi(_pick_scroll, 0, maxi(_pick_rooms.size() - PICK_ROWS, 0))


# --------------------------------------------------------------- delete ---

func _delete_key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z:
			Sandbox.remove(_room_index())
			cursor = clampi(cursor, 0, _count() - 1)
			_mode = MODE_LIST
			_toast_key("sandbox.deleted")
			Audio.play("menu_back")
		KEY_ESCAPE, KEY_X:
			_mode = MODE_LIST


# ---------------------------------------------------------------- share ---

## Export writes a file *and* puts a share code on the clipboard, because the
## two ways people actually pass a room around are "send the file" and "paste
## it into a chat".
## Width the share panel has for text, and the width its lines are wrapped to.
const SHARE_PANEL := 432.0
const SHARE_TEXT := SHARE_PANEL - 24.0


func _share(room: Dictionary) -> void:
	var path := Sandbox.export_room(room)
	var code := Sandbox.encode(room)
	DisplayServer.clipboard_set(code)

	_share_lines = []
	_share_say(Lang.t("share.file"))
	_share_path(path)
	_share_say("")
	_share_say(Lang.tf("share.code", [code.length()]))
	_share_say("")
	_share_say(Lang.t("share.campaign"))
	_share_say(Lang.t("share.campaign2"))
	_mode = MODE_SHARE
	Audio.play("menu_select")


func _share_all() -> void:
	var rooms := Sandbox.all()
	if rooms.is_empty():
		_toast_key("sandbox.empty")
		return
	var path := Sandbox.export_all(rooms)

	_share_lines = []
	_share_say(Lang.tf("share.pack", [rooms.size()]))
	_share_path(path)
	_share_say("")
	_share_say(Lang.t("share.campaign"))
	_share_say(Lang.t("share.campaign2"))
	_mode = MODE_SHARE
	Audio.play("menu_select")


func _share_say(text: String) -> void:
	for line: String in PixelFont.wrap(text, SHARE_TEXT, 1):
		_share_lines.append({"text": line, "accent": false})


## A path is the one line here that has no length anybody controls: a deep home
## directory and a long room name together ran off both edges of the panel.
## Wrapped, it takes as many lines as it needs and the panel grows to hold them.
func _share_path(path: String) -> void:
	if path.is_empty():
		_share_lines.append({"text": Lang.t("share.failed"), "accent": true})
		return
	for line: String in PixelFont.wrap(path.to_upper(), SHARE_TEXT, 1):
		_share_lines.append({"text": line, "accent": true})


# --------------------------------------------------------------- import ---

func _open_import() -> void:
	_import_items = [{"kind": "clipboard", "label": Lang.t("import.clipboard")}]
	for file: Dictionary in Sandbox.drop_files():
		_import_items.append({"kind": "file", "label": file["label"], "path": file["path"]})
	_import_cursor = 0
	_mode = MODE_IMPORT
	Audio.play("menu_select")


func _import_key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_UP, KEY_W:
			_import_cursor = wrapi(_import_cursor - 1, 0, _import_items.size())
			Audio.play("menu_move")
		KEY_DOWN, KEY_S:
			_import_cursor = wrapi(_import_cursor + 1, 0, _import_items.size())
			Audio.play("menu_move")
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z:
			_run_import()
		KEY_ESCAPE, KEY_X:
			_mode = MODE_LIST
			Audio.play("menu_back")


func _run_import() -> void:
	var item: Dictionary = _import_items[_import_cursor]
	var rooms: Array = []
	if item["kind"] == "clipboard":
		rooms = Sandbox.rooms_from_text(DisplayServer.clipboard_get())
	else:
		rooms = Sandbox.read_file(str(item["path"]))

	if rooms.is_empty():
		_toast_key("import.failed")
		Audio.play("menu_back")
		return

	var added := Sandbox.import_rooms(rooms)
	_mode = MODE_LIST
	cursor = Sandbox.all().size()
	_toast = Lang.tf("import.done", [added])
	_toast_time = 2.6
	Audio.play("menu_select")


func _toast_key(key: String) -> void:
	_toast = Lang.t(key)
	_toast_time = 2.2


# ----------------------------------------------------------------- draw ---

func _card_rect(i: int) -> Rect2:
	var col := i % COLUMNS
	var row := i / COLUMNS - _scroll
	return Rect2(ORIGIN + Vector2(col * (CARD.x + GAP.x), row * (CARD.y + GAP.y)), CARD)


func _follow_cursor() -> void:
	var row := cursor / COLUMNS
	var rows_total := (_count() + COLUMNS - 1) / COLUMNS
	_scroll = clampi(_scroll, row - VISIBLE_ROWS + 1, row)
	_scroll = clampi(_scroll, 0, maxi(rows_total - VISIBLE_ROWS, 0))


func _draw() -> void:
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Palette.BG)
	PixelFont.draw_text_centered_shadow(self, Lang.t("sandbox.title"), SCREEN.x * 0.5, 16.0,
		Palette.WHITE, Palette.MAGENTA_DARK, 2)

	_follow_cursor()
	for i in _count():
		var row := i / COLUMNS - _scroll
		if row < 0 or row >= VISIBLE_ROWS:
			continue
		if i == 0:
			_draw_new_card(_card_rect(i), cursor == 0)
		else:
			_draw_room_card(_card_rect(i), Sandbox.all()[i - 1], cursor == i)

	PixelFont.draw_text_centered(self, Lang.t("sandbox.footer"), SCREEN.x * 0.5,
		SCREEN.y - 26.0, Palette.GREY_DARK, 1)
	PixelFont.draw_text_centered(self, Lang.t("sandbox.footer2"), SCREEN.x * 0.5,
		SCREEN.y - 14.0, Palette.GREY_DARK, 1)

	match _mode:
		MODE_DELETE:
			_draw_delete()
		MODE_IMPORT:
			_draw_import()
		MODE_SHARE:
			_draw_share()
		MODE_SOURCE:
			_draw_source()
		MODE_PICK:
			_draw_pick()

	if _toast_time > 0.0:
		_draw_toast()


func _border(selected: bool) -> Color:
	if not selected:
		return Palette.FRAME
	return Palette.MAGENTA if fmod(_time, 0.8) < 0.4 else Palette.WHITE


func _draw_new_card(rect: Rect2, selected: bool) -> void:
	Util.draw_panel(self, rect, Palette.BG_SOFT, _border(selected))
	var cx := rect.position.x + rect.size.x * 0.5
	var cy := rect.position.y + rect.size.y * 0.5

	# A plus sign built out of two rectangles: the font has one, but not at a
	# size that reads as a button.
	var arm := 16.0
	var color := Palette.WHITE if selected else Palette.GREY_DARK
	draw_rect(Rect2(cx - arm * 0.5, cy - 12.0 - 2.0, arm, 4), color)
	draw_rect(Rect2(cx - 2.0, cy - 12.0 - arm * 0.5, 4, arm), color)
	PixelFont.draw_text_centered(self, Lang.t("sandbox.new"), cx, cy + 12.0, color, 1)


func _draw_room_card(rect: Rect2, room: Dictionary, selected: bool) -> void:
	Util.draw_panel(self, rect, Palette.BG_SOFT, _border(selected))

	var preview := Rect2(rect.position + Vector2(6, 4), Vector2(120, 64))
	draw_rect(preview, Palette.BG)
	RoomPreview.draw(self, room["rows"], preview)

	var cx := rect.position.x + rect.size.x * 0.5
	PixelFont.draw_text_centered(self, str(room["name"]), cx, rect.position.y + 70.0,
		Palette.WHITE if selected else Palette.GREY, 1)

	# What the room is made of, in one line: gems, then the par it was set to.
	var gems := Sandbox.count_char(room, "o")
	var meta := Lang.tf("sandbox.meta", [gems, Util.format_time(float(room["par"]))])
	PixelFont.draw_text_centered(self, meta, cx, rect.position.y + 80.0, Palette.GOLD_DARK, 1)

	if not Sandbox.is_playable(room):
		PixelFont.draw_text(self, "!", rect.position + Vector2(4, 4), Palette.MAGENTA, 1)


func _dim() -> void:
	var dim := Palette.BG
	dim.a = 0.92
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), dim)


func _draw_delete() -> void:
	_dim()
	var panel := Rect2(90, 100, 300, 70)
	Util.draw_panel(self, panel, Palette.BG_SOFT, Palette.MAGENTA_DARK)
	var cx := panel.position.x + panel.size.x * 0.5
	PixelFont.draw_text_centered(self, Lang.t("sandbox.delete"), cx,
		panel.position.y + 14.0, Palette.WHITE, 1)
	PixelFont.draw_text_centered(self, str(Sandbox.all()[_room_index()]["name"]), cx,
		panel.position.y + 30.0, Palette.MAGENTA, 1)
	PixelFont.draw_text_centered(self, Lang.t("sandbox.delete_footer"), cx,
		panel.position.y + 50.0, Palette.GREY_DARK, 1)


func _draw_import() -> void:
	_dim()
	var height := 60.0 + _import_items.size() * 14.0
	var panel := Rect2(70, roundf((SCREEN.y - height) * 0.5), 340, height)
	Util.draw_panel(self, panel, Palette.BG_SOFT, Palette.FRAME)
	var cx := panel.position.x + panel.size.x * 0.5

	PixelFont.draw_text_centered(self, Lang.t("import.title"), cx,
		panel.position.y + 10.0, Palette.WHITE, 2)

	for i in _import_items.size():
		var y := panel.position.y + 34.0 + i * 14.0
		var selected := i == _import_cursor
		# A filename is as long as somebody made it; the panel is not.
		PixelFont.draw_text(self, _clip(str(_import_items[i]["label"]), 292.0),
			Vector2(panel.position.x + 24.0, y),
			Palette.WHITE if selected else Palette.GREY_DARK, 1)
		if selected:
			PixelFont.draw_text(self, ">", Vector2(panel.position.x + 12.0, y),
				Palette.MAGENTA, 1)

	PixelFont.draw_text_centered(self, Lang.t("import.footer"), cx,
		panel.position.y + panel.size.y - 16.0, Palette.GREY_DARK, 1)


func _draw_share() -> void:
	_dim()
	var height := 46.0 + _share_lines.size() * 12.0
	var panel := Rect2(24, roundf((SCREEN.y - height) * 0.5), SHARE_PANEL, height)
	Util.draw_panel(self, panel, Palette.BG_SOFT, Palette.FRAME)
	var cx := panel.position.x + panel.size.x * 0.5

	PixelFont.draw_text_centered(self, Lang.t("share.title"), cx,
		panel.position.y + 10.0, Palette.WHITE, 2)

	for i in _share_lines.size():
		var line: Dictionary = _share_lines[i]
		var text := str(line["text"])
		if text.is_empty():
			continue
		PixelFont.draw_text_centered(self, text, cx,
			panel.position.y + 32.0 + i * 12.0,
			Palette.CYAN if bool(line["accent"]) else Palette.GREY, 1)

	PixelFont.draw_text_centered(self, Lang.t("share.footer"), cx,
		panel.position.y + panel.size.y - 14.0, Palette.GREY_DARK, 1)


func _draw_source() -> void:
	_dim()
	var height := 54.0 + _source_items.size() * 16.0
	var panel := Rect2(90, roundf((SCREEN.y - height) * 0.5), 300, height)
	Util.draw_panel(self, panel, Palette.BG_SOFT, Palette.FRAME)
	var cx := panel.position.x + panel.size.x * 0.5

	PixelFont.draw_text_centered(self, Lang.t("sandbox.new_title"), cx,
		panel.position.y + 10.0, Palette.WHITE, 2)

	for i in _source_items.size():
		var y := panel.position.y + 34.0 + i * 16.0
		var selected := i == _source_cursor
		PixelFont.draw_text(self, str(_source_items[i]["label"]),
			Vector2(panel.position.x + 26.0, y),
			Palette.WHITE if selected else Palette.GREY_DARK, 1)
		if selected:
			PixelFont.draw_text(self, ">", Vector2(panel.position.x + 14.0, y),
				Palette.MAGENTA, 1)

	PixelFont.draw_text_centered(self, Lang.t("sandbox.src_footer"), cx,
		panel.position.y + panel.size.y - 14.0, Palette.GREY_DARK, 1)


## Names on the left, one large preview on the right. The preview is the whole
## point: room names in a campaign are deliberately evocative rather than
## descriptive, and "GANANCIA" tells you nothing about what you are copying.
func _draw_pick() -> void:
	_dim()
	var panel := Rect2(20, 24, 440, 222)
	Util.draw_panel(self, panel, Palette.BG_SOFT, Palette.FRAME)
	PixelFont.draw_text_centered(self, _pick_title,
		panel.position.x + panel.size.x * 0.5, panel.position.y + 8.0, Palette.WHITE, 2)

	var list_x := panel.position.x + 12.0
	var top := panel.position.y + 30.0

	for row in mini(PICK_ROWS, _pick_rooms.size()):
		var i := _pick_scroll + row
		if i >= _pick_rooms.size():
			break
		var entry: Dictionary = _pick_rooms[i]
		var y := top + row * PICK_LINE
		var selected := i == _pick_cursor
		if selected:
			draw_rect(Rect2(list_x - 4.0, y - 2.0, 172.0, PICK_LINE),
				Color(Palette.CYAN, 0.18))
		PixelFont.draw_text(self, "%02d" % (i + 1), Vector2(list_x, y),
			Palette.GREY_DARK, 1)
		PixelFont.draw_text(self, _clip(str(entry["name"]), 138.0),
			Vector2(list_x + 20.0, y), Palette.WHITE if selected else Palette.GREY, 1)

	if _pick_rooms.size() > PICK_ROWS:
		# A thumb on the left edge, so a list eight screens long says so.
		var track := Rect2(panel.position.x + 4.0, top, 2.0, PICK_ROWS * PICK_LINE)
		draw_rect(track, Palette.FRAME)
		var span := float(PICK_ROWS) / float(_pick_rooms.size())
		draw_rect(Rect2(track.position.x,
			track.position.y + track.size.y * float(_pick_scroll) / float(_pick_rooms.size()),
			2.0, maxf(track.size.y * span, 6.0)), Palette.CYAN_DARK)

	_draw_pick_preview(panel, top)

	PixelFont.draw_text_centered(self, Lang.t("pick.footer"),
		panel.position.x + panel.size.x * 0.5, panel.position.y + panel.size.y - 14.0,
		Palette.GREY_DARK, 1)


func _draw_pick_preview(panel: Rect2, top: float) -> void:
	if _pick_rooms.is_empty():
		return
	var entry: Dictionary = _pick_rooms[_pick_cursor]

	# Four pixels a tile: the largest whole multiple that fits, so the preview
	# stays on the pixel grid the rest of the game lives on. Pinned to the
	# panel's right margin rather than to a hand-picked column, so widening the
	# name list can never push it off the edge.
	var size := Vector2(Levels.COLS * 4, Levels.ROWS * 4)
	var frame := Rect2(Vector2(panel.position.x + panel.size.x - 8.0 - size.x, top), size)
	draw_rect(frame, Palette.BG)
	RoomPreview.draw(self, entry["rows"], frame)
	Util.draw_panel(self, frame, Color(0, 0, 0, 0), Palette.FRAME)

	var cx := frame.position.x + frame.size.x * 0.5
	PixelFont.draw_text_centered(self, str(entry["name"]), cx,
		frame.position.y + frame.size.y + 8.0, Palette.WHITE, 1)

	var gems := 0
	for row: String in entry["rows"]:
		gems += row.count("o")
	PixelFont.draw_text_centered(self,
		Lang.tf("sandbox.meta", [gems, Util.format_time(float(entry["par"]))]),
		cx, frame.position.y + frame.size.y + 20.0, Palette.GOLD_DARK, 1)


## Cut a name to whatever fits. The font is fixed pitch, so this is division.
func _clip(text: String, width: float) -> String:
	var fits := floori(width / float(PixelFont.advance(1)))
	return text if text.length() <= fits else text.substr(0, maxi(fits, 0))


func _draw_toast() -> void:
	var size := PixelFont.measure(_toast, 1)
	var rect := Rect2(roundf((SCREEN.x - size.x) * 0.5) - 6.0, 30.0, size.x + 12.0, 14.0)
	Util.draw_panel(self, rect, Palette.BG, Palette.FRAME)
	PixelFont.draw_text_centered(self, _toast, SCREEN.x * 0.5, rect.position.y + 4.0,
		Palette.WHITE, 1)
