class_name CodexScreen
extends Node2D

## The book, as a grid of cards you fill in by playing.
##
## Entries you have not met still take up their slot, drawn as a question mark.
## Showing the shape of what is missing is the whole reason a collection screen
## is worth having — a list that only grows tells you nothing about how far in
## you are.

signal cancelled

const SCREEN := Vector2(480, 270)
const COLUMNS := 6
const CARD := Vector2(70, 52)
const GAP := Vector2(6, 6)
const ORIGIN := Vector2(20, 46)
const VISIBLE_ROWS := 3

var cursor := 0
var opaque := true
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_time += delta
	_handle_input()
	queue_redraw()


func _handle_input() -> void:
	var moved := false
	if Input.is_action_just_pressed("p_right"):
		cursor = wrapi(cursor + 1, 0, Codex.count())
		moved = true
	elif Input.is_action_just_pressed("p_left"):
		cursor = wrapi(cursor - 1, 0, Codex.count())
		moved = true
	elif Input.is_action_just_pressed("p_down"):
		cursor = wrapi(cursor + COLUMNS, 0, Codex.count())
		moved = true
	elif Input.is_action_just_pressed("p_up"):
		cursor = wrapi(cursor - COLUMNS, 0, Codex.count())
		moved = true

	if moved:
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_cancel") or Input.is_action_just_pressed("p_accept"):
		Audio.play("menu_back")
		cancelled.emit()


func _scroll() -> int:
	var row := cursor / COLUMNS
	var rows_total := (Codex.count() + COLUMNS - 1) / COLUMNS
	var top := clampi(row - VISIBLE_ROWS + 1, 0, maxi(rows_total - VISIBLE_ROWS, 0))
	return clampi(top, 0, row)


# -------------------------------------------------------------------- draw ---

func _draw() -> void:
	if opaque:
		draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Palette.BG)
	else:
		var dim := Palette.BG
		dim.a = 0.9
		draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), dim)

	PixelFont.draw_text_centered_shadow(self, Lang.t("codex.title"), SCREEN.x * 0.5, 16.0,
		Palette.WHITE, Palette.MAGENTA_DARK, 2)
	PixelFont.draw_text_centered(self, Lang.tf("codex.found",
		[Save.known_count(), Codex.count()]), SCREEN.x * 0.5, 34.0, Palette.GREY_DARK, 1)

	var top := _scroll()
	for i in Codex.count():
		var row := i / COLUMNS - top
		if row < 0 or row >= VISIBLE_ROWS:
			continue
		_draw_card(i, row)

	_draw_detail()


func _draw_card(i: int, row: int) -> void:
	var entry: Dictionary = Codex.ENTRIES[i]
	var known := Save.knows(entry["id"])
	var selected := i == cursor
	var col := i % COLUMNS
	var rect := Rect2(
		ORIGIN + Vector2(col * (CARD.x + GAP.x), row * (CARD.y + GAP.y)),
		CARD
	)

	var border := Palette.FRAME
	if selected:
		border = Palette.MAGENTA if fmod(_time, 0.8) < 0.4 else Palette.WHITE
	elif known:
		border = Palette.CYAN_DARK
	Util.draw_panel(self, rect, Palette.BG_SOFT if known else Palette.BG, border)

	var centre := rect.position + Vector2(rect.size.x * 0.5, 20.0)
	if known:
		var tex := PixelArt.tex(entry["sprite"])
		# Icons are 8px; the door is 16 tall, so centre whatever comes back.
		var scale := 2.0 if tex.get_height() <= 8 else 1.0
		var size := Vector2(tex.get_width(), tex.get_height()) * scale
		draw_texture_rect(tex, Rect2(
			Vector2(roundf(centre.x - size.x * 0.5), roundf(centre.y - size.y * 0.5)),
			size), false)
		PixelFont.draw_text_centered(self, _short(Lang.t("codex." + entry["id"] + ".name")),
			rect.position.x + rect.size.x * 0.5, rect.position.y + 38.0,
			Palette.WHITE if selected else Palette.GREY, 1)
	else:
		PixelFont.draw_text_centered(self, "?", centre.x, centre.y - 7.0,
			Palette.GREY_DARK, 2)


## Card width holds eleven glyphs at scale 1.
func _short(text: String) -> String:
	return text if text.length() <= 11 else text.substr(0, 11)


## The panel along the bottom: the full name and what the thing actually does.
func _draw_detail() -> void:
	var entry: Dictionary = Codex.ENTRIES[cursor]
	var known := Save.knows(entry["id"])
	var panel := Rect2(20.0, 218.0, SCREEN.x - 40.0, 34.0)
	Util.draw_panel(self, panel, Palette.BG_SOFT, Palette.FRAME)

	if not known:
		PixelFont.draw_text_centered(self, Lang.t("codex.unknown"), SCREEN.x * 0.5,
			panel.position.y + 13.0, Palette.GREY_DARK, 1)
		return

	PixelFont.draw_text(self, Lang.t("codex." + entry["id"] + ".name"),
		Vector2(panel.position.x + 8.0, panel.position.y + 7.0), Palette.CYAN, 1)
	PixelFont.draw_text(self, Lang.t("codex." + entry["id"] + ".text"),
		Vector2(panel.position.x + 8.0, panel.position.y + 20.0), Palette.GREY, 1)

	PixelFont.draw_text_centered(self, Lang.t("codex.footer"), SCREEN.x * 0.5,
		SCREEN.y - 12.0, Palette.GREY_DARK, 1)
