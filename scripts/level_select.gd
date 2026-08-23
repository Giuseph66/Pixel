class_name LevelSelect
extends Node2D

## Twelve cards, four across, three rows down.
##
## A card is read top to bottom: number, name, best time, gems, and a bar along
## the bottom edge showing gem progress at a glance. Room names are wrapped
## across two lines rather than clipped, because a name like "CUIDADO COM O
## VÃO" is wider than any single line a 100px card can hold.

signal picked(index: int)
signal cancelled

const SCREEN := Vector2(480, 270)
const COLUMNS := 4
const CARD := Vector2(100, 62)
const GAP := Vector2(8, 8)
const ORIGIN := Vector2(28, 44)

const PAD := 5.0
const NAME_LINES := 2
## Glyphs are 5px plus 1px tracking, so 90px of usable width holds 15 of them.
const NAME_CHARS := 15

## Baselines inside a card, measured from the padded origin.
const ROW_NAME := 16.0
const ROW_LINE := 8.0
const ROW_TIME := 34.0
const ROW_GEMS := 43.0

var cursor := 0
var _levels: Array = []
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_levels = Levels.all()
	# Start on the first room that is still unfinished.
	for i in _levels.size():
		if Save.is_unlocked(i) and not Save.is_cleared(i):
			cursor = i
			break


func _process(delta: float) -> void:
	_time += delta
	_handle_input()
	queue_redraw()


func _handle_input() -> void:
	var moved := false
	if Input.is_action_just_pressed("p_right"):
		cursor = wrapi(cursor + 1, 0, _levels.size())
		moved = true
	elif Input.is_action_just_pressed("p_left"):
		cursor = wrapi(cursor - 1, 0, _levels.size())
		moved = true
	elif Input.is_action_just_pressed("p_down"):
		cursor = wrapi(cursor + COLUMNS, 0, _levels.size())
		moved = true
	elif Input.is_action_just_pressed("p_up"):
		cursor = wrapi(cursor - COLUMNS, 0, _levels.size())
		moved = true

	if moved:
		Audio.play("menu_move")
		return

	if Input.is_action_just_pressed("p_accept"):
		if Save.is_unlocked(cursor):
			Audio.play("menu_select")
			picked.emit(cursor)
		else:
			Audio.play("menu_back")
	elif Input.is_action_just_pressed("p_cancel"):
		Audio.play("menu_back")
		cancelled.emit()


func _card_rect(i: int) -> Rect2:
	var col := i % COLUMNS
	var row := i / COLUMNS
	return Rect2(
		ORIGIN + Vector2(col * (CARD.x + GAP.x), row * (CARD.y + GAP.y)),
		CARD
	)


# -------------------------------------------------------------------- draw ---

func _draw() -> void:
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Palette.BG)
	PixelFont.draw_text_centered_shadow(self, Lang.t("select.title"), SCREEN.x * 0.5, 22.0,
		Palette.WHITE, Palette.MAGENTA_DARK, 2)

	for i in _levels.size():
		_draw_card(i)

	PixelFont.draw_text_centered(self, Lang.t("select.footer"),
		SCREEN.x * 0.5, SCREEN.y - 14.0, Palette.GREY_DARK, 1)


func _draw_card(i: int) -> void:
	var rect := _card_rect(i)
	var unlocked := Save.is_unlocked(i)
	var cleared := Save.is_cleared(i)
	var selected := i == cursor
	var blink := fmod(_time, 0.8) < 0.4

	# A locked card never pulses in the accent colour: the highlight should not
	# promise something the button will refuse.
	var border := Palette.FRAME
	if selected:
		if unlocked:
			border = Palette.MAGENTA if blink else Palette.WHITE
		else:
			border = Palette.GREY_DARK if blink else Palette.FRAME
	elif cleared:
		border = Palette.CYAN_DARK

	Util.draw_panel(self, rect, Palette.BG_SOFT if unlocked else Palette.BG, border)

	var origin := rect.position + Vector2(PAD, PAD)
	PixelFont.draw_text(self, "%02d" % (i + 1), origin,
		Palette.CYAN if unlocked else Palette.GREY_DARK, 2)

	if not unlocked:
		_draw_lock(rect.position + Vector2(rect.size.x - 12.0, PAD + 3.0), Palette.GREY_DARK)
		PixelFont.draw_text(self, Lang.t("select.locked"),
			origin + Vector2(0, 22), Palette.GREY_DARK, 1)
		return

	if cleared:
		PixelFont.draw_text(self, "*", rect.position + Vector2(rect.size.x - 13.0, PAD),
			Palette.GOLD, 2)

	var data: Dictionary = _levels[i]
	var lines := _wrap(Lang.t(data["name"]), NAME_CHARS, NAME_LINES)
	for line_index in lines.size():
		PixelFont.draw_text(self, lines[line_index],
			origin + Vector2(0, ROW_NAME + line_index * ROW_LINE),
			Palette.WHITE if selected else Palette.GREY, 1)

	var best := Save.best_time(i)
	var under_par := best > 0.0 and best <= float(data["par"])
	PixelFont.draw_text(self, Lang.t("select.time") + Util.format_time(best),
		origin + Vector2(0, ROW_TIME), Palette.GOLD if under_par else Palette.GREY_DARK, 1)

	var taken := Save.best_gems(i)
	var total := _count_gems(data["rows"])
	var all_gems := total > 0 and taken >= total
	PixelFont.draw_text(self, Lang.tf("select.gems", [taken, total]),
		origin + Vector2(0, ROW_GEMS), Palette.GOLD if all_gems else Palette.GREY_DARK, 1)

	_draw_gem_bar(rect, taken, total, all_gems)


## Thin progress bar hugging the bottom edge, so a glance across the grid shows
## which rooms still owe you gems without reading a single number.
func _draw_gem_bar(rect: Rect2, taken: int, total: int, complete: bool) -> void:
	if total <= 0:
		return
	var width := rect.size.x - PAD * 2
	var y := rect.position.y + rect.size.y - 5.0
	draw_rect(Rect2(rect.position.x + PAD, y, width, 2), Palette.FRAME)
	var filled := roundf(width * (float(taken) / float(total)))
	if filled > 0.0:
		draw_rect(Rect2(rect.position.x + PAD, y, filled, 2),
			Palette.GOLD if complete else Palette.CYAN_DARK)


## Five by seven padlock, drawn from rectangles like everything else.
func _draw_lock(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos.x + 1, pos.y, 3, 1), color)
	draw_rect(Rect2(pos.x, pos.y + 1, 1, 2), color)
	draw_rect(Rect2(pos.x + 4, pos.y + 1, 1, 2), color)
	draw_rect(Rect2(pos.x, pos.y + 3, 5, 4), color)


## Greedy word wrap. Anything that still will not fit is cut with a period, so
## a long name degrades instead of running off the card.
func _wrap(text: String, chars: int, max_lines: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var candidate: String = word if line.is_empty() else line + " " + word
		if candidate.length() <= chars:
			line = candidate
			continue
		if not line.is_empty():
			out.append(line)
			if out.size() == max_lines:
				return _truncate_last(out, text, chars)
		line = word
	if not line.is_empty():
		out.append(line)
	return _truncate_last(out, text, chars)


func _truncate_last(lines: PackedStringArray, full: String, chars: int) -> PackedStringArray:
	var used := 0
	for line in lines:
		used += line.length() + 1
	if used - 1 < full.length() and lines.size() > 0:
		var last: String = lines[lines.size() - 1]
		if last.length() >= chars:
			last = last.substr(0, chars - 1)
		lines[lines.size() - 1] = last + "."
	for i in lines.size():
		if lines[i].length() > chars:
			lines[i] = lines[i].substr(0, chars)
	return lines


func _count_gems(rows: PackedStringArray) -> int:
	var n := 0
	for row in rows:
		n += row.count("o")
	return n
