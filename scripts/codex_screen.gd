class_name CodexScreen
extends Node2D

## The book: a two-page spread with a bound spine and four chapter tabs down
## its left edge.
##
## Up/Down turns to another chapter (abilities, creatures, collectibles,
## world). Left/Right turns pages inside the chapter — left page is that
## chapter's contents, right page is the entry, drawn large.
##
## Entries you have not met still hold their slot, marked "???". The shape of
## what is missing is the point of a collection screen; a list that only grows
## tells you nothing about how far in you are.

signal cancelled

const SCREEN := Vector2(480, 270)

## Cover is drawn 4px outside this, so the plate spans y 22..246.
const BOOK := Rect2(56, 26, 382, 216)
const SPINE_W := 6.0
const COVER := 4.0

const TAB_SIZE := Vector2(26, 42)
const TAB_GAP := 6.0
const TAB_POKE := 3.0           # extra width on the selected tab

const PAD := 10.0
const ROW_H := 20.0
const LIST_TOP := 30.0
const LIST_ROWS := 8

## All codex sprites are 8x8, so these land on exact integer scales.
const ICON_LIST := 16.0         # target size in the contents list
const ICON_PAGE := 40.0         # target size on the entry page

var chapter := 0
var index := 0
var opaque := true
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_time += delta
	_handle_input()
	queue_redraw()


func _current_entries() -> Array:
	return Codex.in_chapter(Codex.CHAPTERS[chapter]["kind"])


func _handle_input() -> void:
	var entries := _current_entries()
	var moved := false

	if Input.is_action_just_pressed("p_down"):
		chapter = wrapi(chapter + 1, 0, Codex.CHAPTERS.size())
		index = 0
		moved = true
	elif Input.is_action_just_pressed("p_up"):
		chapter = wrapi(chapter - 1, 0, Codex.CHAPTERS.size())
		index = 0
		moved = true
	elif Input.is_action_just_pressed("p_right") and entries.size() > 1:
		index = wrapi(index + 1, 0, entries.size())
		moved = true
	elif Input.is_action_just_pressed("p_left") and entries.size() > 1:
		index = wrapi(index - 1, 0, entries.size())
		moved = true

	if moved:
		Audio.play("menu_move")
		return

	if Input.is_action_just_pressed("p_cancel") or Input.is_action_just_pressed("p_accept"):
		Audio.play("menu_back")
		cancelled.emit()


# ------------------------------------------------------------------ layout ---

func _page_width() -> float:
	return (BOOK.size.x - SPINE_W) * 0.5


func _left_page() -> Rect2:
	return Rect2(BOOK.position, Vector2(_page_width(), BOOK.size.y))


func _right_page() -> Rect2:
	return Rect2(BOOK.position + Vector2(_page_width() + SPINE_W, 0.0),
		Vector2(_page_width(), BOOK.size.y))


func _chapter_color() -> Color:
	return Codex.CHAPTERS[chapter]["color"]


# -------------------------------------------------------------------- draw ---

func _draw() -> void:
	if opaque:
		draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Palette.BG)
	else:
		var dim := Palette.BG
		dim.a = 0.92
		draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), dim)

	PixelFont.draw_text_centered_shadow(self, Lang.t("codex.title"), SCREEN.x * 0.5, 3.0,
		Palette.WHITE, Palette.MAGENTA_DARK, 2)

	_draw_cover()
	_draw_tabs()
	_draw_contents_page(_left_page())
	_draw_entry_page(_right_page())
	_draw_spine()

	PixelFont.draw_text_centered(self, Lang.t("codex.footer"), SCREEN.x * 0.5, SCREEN.y - 12.0,
		Palette.GREY_DARK, 1)


## Gold trim showing around both pages.
func _draw_cover() -> void:
	draw_rect(BOOK.grow(COVER), Palette.GOLD_DARK)
	draw_rect(BOOK.grow(COVER - 1.0), Palette.OUTLINE)


## Solid binding with a continuous gold rule up each side. The old version drew
## dashes down the middle, which read as a broken divider rather than a spine.
func _draw_spine() -> void:
	var x := BOOK.position.x + _page_width()
	draw_rect(Rect2(x, BOOK.position.y, SPINE_W, BOOK.size.y), Palette.OUTLINE)
	draw_rect(Rect2(x, BOOK.position.y, 1.0, BOOK.size.y), Palette.GOLD_DARK)
	draw_rect(Rect2(x + SPINE_W - 1.0, BOOK.position.y, 1.0, BOOK.size.y), Palette.GOLD_DARK)


func _draw_tabs() -> void:
	var count := Codex.CHAPTERS.size()
	var total := count * TAB_SIZE.y + (count - 1) * TAB_GAP
	var top := BOOK.position.y + (BOOK.size.y - total) * 0.5

	for i in count:
		var ch: Dictionary = Codex.CHAPTERS[i]
		var selected := i == chapter
		var entries := Codex.in_chapter(ch["kind"])
		var found := 0
		for e: Dictionary in entries:
			if Save.knows(e["id"]):
				found += 1

		# The selected tab is pulled a few pixels further out of the book.
		var poke := TAB_POKE if selected else 0.0
		var rect := Rect2(BOOK.position.x - TAB_SIZE.x - poke,
			top + i * (TAB_SIZE.y + TAB_GAP), TAB_SIZE.x + poke, TAB_SIZE.y)

		var color: Color = ch["color"]
		draw_rect(rect, color if selected else color.darkened(0.6))
		# Outline everything except the edge tucked under the page.
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), Palette.OUTLINE)
		draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - 1.0),
			Vector2(rect.size.x, 1.0)), Palette.OUTLINE)
		draw_rect(Rect2(rect.position, Vector2(1.0, rect.size.y)), Palette.OUTLINE)

		# Two letters of the untranslated kind id. "CREATURES" and
		# "COLLECTIBLES" both start with C in every language here, so a single
		# letter taken from the label would not tell the tabs apart.
		var code := str(ch["kind"]).left(2).to_upper()
		var ink := Palette.OUTLINE if selected else Palette.GREY
		var cx := rect.position.x + rect.size.x * 0.5
		PixelFont.draw_text_centered(self, code, cx, rect.position.y + 8.0, ink, 2)
		PixelFont.draw_text_centered(self, "%d/%d" % [found, entries.size()],
			cx, rect.position.y + 26.0, ink, 1)


## Left page: the chapter's contents, one row per entry.
func _draw_contents_page(page: Rect2) -> void:
	Util.draw_panel(self, page, Palette.BG_SOFT, Palette.FRAME)

	var ch: Dictionary = Codex.CHAPTERS[chapter]
	var color: Color = ch["color"]
	PixelFont.draw_text(self, Lang.t(ch["label"]),
		page.position + Vector2(PAD, 8.0), color, 2)

	draw_rect(Rect2(page.position.x + PAD, page.position.y + 24.0,
		page.size.x - PAD * 2.0, 1.0), Palette.FRAME)

	# Overall progress sits at the foot of the page. Sharing the heading line
	# with the chapter name did not work: "HABILIDADES" at this scale is 130px
	# wide in a 188px page, so the two ran straight through each other.
	var found := Lang.tf("codex.found", [Save.known_count(), Codex.count()])
	PixelFont.draw_text(self, found,
		Vector2(page.position.x + PAD, page.position.y + page.size.y - 14.0),
		Palette.GREY_DARK, 1)

	var entries := _current_entries()
	var first := clampi(index - (LIST_ROWS - 1), 0, maxi(0, entries.size() - LIST_ROWS))
	var last := mini(first + LIST_ROWS, entries.size())
	for i in range(first, last):
		_draw_contents_row(page, entries[i], i, i - first)


func _draw_contents_row(page: Rect2, entry: Dictionary, i: int, row_index: int) -> void:
	var y := page.position.y + LIST_TOP + row_index * ROW_H
	var selected := i == index
	var known := Save.knows(entry["id"])

	if selected:
		var row := Rect2(page.position.x + 3.0, y, page.size.x - 6.0, ROW_H - 2.0)
		draw_rect(row, Palette.BG)
		# Accent bar in the chapter colour, so the selection is readable even
		# where the fill barely differs from the page.
		draw_rect(Rect2(row.position, Vector2(2.0, row.size.y)), _chapter_color())

	var mid := y + (ROW_H - 2.0) * 0.5
	if known:
		_draw_icon(entry["sprite"], Vector2(page.position.x + 18.0, mid), ICON_LIST)
	else:
		PixelFont.draw_text_centered(self, "?", page.position.x + 18.0, mid - 3.0,
			Palette.GREY_DARK, 1)

	var label := Lang.t("codex." + entry["id"] + ".name") if known else "???"
	var ink := Palette.GREY_DARK
	if known:
		ink = Palette.WHITE if selected else Palette.GREY
	PixelFont.draw_text(self, label, Vector2(page.position.x + 32.0, mid - 3.0), ink, 1)


## Right page: the entry itself.
func _draw_entry_page(page: Rect2) -> void:
	Util.draw_panel(self, page, Palette.BG_SOFT, Palette.FRAME)

	var entries := _current_entries()
	if entries.is_empty():
		return

	var entry: Dictionary = entries[index]
	var known := Save.knows(entry["id"])
	var cx := page.position.x + page.size.x * 0.5
	var color := _chapter_color()

	var plate := Rect2(cx - 76.0, page.position.y + 12.0, 152.0, 80.0)
	var fill := color
	fill.a = 0.16
	draw_rect(plate, fill)
	_draw_plate_corners(plate, color)

	if not known:
		PixelFont.draw_text_centered(self, "?", cx,
			plate.position.y + plate.size.y * 0.5 - 14.0, Palette.GREY_DARK, 4)
	else:
		# The entry acting itself out, with the real sprites and the real timing.
		# Anything without an animation falls back to its glyph.
		if not CodexPreview.draw(self, entry["id"], plate, _time):
			var bob := roundf(sin(_time * 2.0) * 2.0)
			_draw_icon(entry["sprite"],
				Vector2(cx, plate.position.y + plate.size.y * 0.5 + bob), ICON_PAGE)

	var y := plate.position.y + plate.size.y + 14.0
	if known:
		PixelFont.draw_text_centered(self, Lang.t("codex." + entry["id"] + ".name"),
			cx, y, Palette.WHITE, 2)
		draw_rect(Rect2(cx - 30.0, y + 18.0, 60.0, 1.0), color)
		_draw_wrapped(Lang.t("codex." + entry["id"] + ".text"),
			Vector2(page.position.x + PAD, y + 26.0), page.size.x - PAD * 2.0, Palette.GREY)
	else:
		PixelFont.draw_text_centered(self, Lang.t("codex.unknown"), cx, y,
			Palette.GREY_DARK, 1)

	_draw_page_dots(page, entries, cx)


## Corner ticks instead of a full border: the plate frames the icon without
## turning into a second panel inside the page.
func _draw_plate_corners(plate: Rect2, color: Color) -> void:
	var arm := 8.0
	var x0 := plate.position.x
	var y0 := plate.position.y
	var x1 := plate.position.x + plate.size.x
	var y1 := plate.position.y + plate.size.y
	for corner: Vector2 in [Vector2(x0, y0), Vector2(x1 - arm, y0),
			Vector2(x0, y1 - 1.0), Vector2(x1 - arm, y1 - 1.0)]:
		draw_rect(Rect2(corner.x, corner.y, arm, 1.0), color)
	for corner: Vector2 in [Vector2(x0, y0), Vector2(x1 - 1.0, y0),
			Vector2(x0, y1 - arm), Vector2(x1 - 1.0, y1 - arm)]:
		draw_rect(Rect2(corner.x, corner.y, 1.0, arm), color)


func _draw_page_dots(page: Rect2, entries: Array, cx: float) -> void:
	if entries.size() <= 1:
		return
	var y := page.position.y + page.size.y - 12.0
	var step := 8.0
	var x := cx - (entries.size() - 1) * step * 0.5
	for i in entries.size():
		var c := Palette.GREY_DARK
		if i == index:
			c = _chapter_color()
		elif Save.knows(entries[i]["id"]):
			c = Palette.GREY
		var size := 4.0 if i == index else 3.0
		draw_rect(Rect2(roundf(x - size * 0.5), roundf(y - size * 0.5), size, size), c)
		x += step


## Word-wrapped body text. A description does not reliably fit one line at this
## page width, and the old single-line draw simply ran off the page edge.
func _draw_wrapped(text: String, pos: Vector2, width: float, color: Color) -> void:
	var max_chars := maxi(1, int((width + 1.0) / float(PixelFont.W + PixelFont.TRACKING)))
	var line := ""
	var y := pos.y
	for word in text.split(" ", false):
		var candidate: String = word if line.is_empty() else line + " " + word
		if candidate.length() > max_chars and not line.is_empty():
			PixelFont.draw_text(self, line, Vector2(pos.x, y), color, 1)
			y += 9.0
			line = word
		else:
			line = candidate
	if not line.is_empty():
		PixelFont.draw_text(self, line, Vector2(pos.x, y), color, 1)


## Integer scale only — a fractional one would smear the pixels. Every codex
## sprite is 8x8, so this lands on a clean multiple for all of them.
func _draw_icon(sprite_name: String, center: Vector2, target: float) -> void:
	var tex := PixelArt.tex(sprite_name)
	var biggest := maxf(float(tex.get_width()), float(tex.get_height()))
	var scale := maxf(1.0, floorf(target / biggest))
	var size := Vector2(tex.get_width(), tex.get_height()) * scale
	draw_texture_rect(tex, Rect2(
		Vector2(roundf(center.x - size.x * 0.5), roundf(center.y - size.y * 0.5)), size), false)
