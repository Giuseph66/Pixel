class_name LevelSelect
extends Node2D

## Six cards, three across. A card shows its best time and gem count once the
## room has been cleared; locked rooms show nothing but their number.

signal picked(index: int)
signal cancelled

const SCREEN := Vector2(480, 270)
const COLUMNS := 3
const CARD := Vector2(132, 80)
const GAP := Vector2(10, 12)
const ORIGIN := Vector2(32, 66)

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


func _draw() -> void:
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Palette.BG)
	PixelFont.draw_text_centered_shadow(self, Lang.t("select.title"), SCREEN.x * 0.5, 24.0,
		Palette.WHITE, Palette.MAGENTA_DARK, 2)

	for i in _levels.size():
		_draw_card(i)

	PixelFont.draw_text_centered(self, Lang.t("select.footer"),
		SCREEN.x * 0.5, SCREEN.y - 16.0, Palette.GREY_DARK, 1)


func _draw_card(i: int) -> void:
	var rect := _card_rect(i)
	var unlocked := Save.is_unlocked(i)
	var cleared := Save.is_cleared(i)
	var selected := i == cursor

	var border := Palette.FRAME
	if selected:
		border = Palette.MAGENTA if fmod(_time, 0.8) < 0.4 else Palette.WHITE
	elif cleared:
		border = Palette.CYAN_DARK

	Util.draw_panel(self, rect, Palette.BG_SOFT if unlocked else Palette.BG, border)

	var pad := rect.position + Vector2(8, 9)
	var number := "%02d" % (i + 1)
	PixelFont.draw_text(self, number, pad, Palette.CYAN if unlocked else Palette.GREY_DARK, 3)

	if not unlocked:
		PixelFont.draw_text(self, Lang.t("select.locked"), pad + Vector2(0, 30), Palette.GREY_DARK, 1)
		return

	var data: Dictionary = _levels[i]
	PixelFont.draw_text(self, Lang.t(data["name"]), pad + Vector2(0, 28),
		Palette.WHITE if selected else Palette.GREY, 1)

	var best := Save.best_time(i)
	PixelFont.draw_text(self, Lang.t("select.time") + Util.format_time(best), pad + Vector2(0, 42),
		Palette.GOLD if best > 0.0 and best <= float(data["par"]) else Palette.GREY_DARK, 1)

	var total := _count_gems(data["rows"])
	PixelFont.draw_text(self, Lang.tf("select.gems", [Save.best_gems(i), total]),
		pad + Vector2(0, 54),
		Palette.GOLD if Save.best_gems(i) >= total and total > 0 else Palette.GREY_DARK, 1)

	if cleared:
		PixelFont.draw_text(self, "*", rect.position + Vector2(rect.size.x - 14, 9),
			Palette.GOLD, 2)


func _count_gems(rows: PackedStringArray) -> int:
	var n := 0
	for row in rows:
		n += row.count("o")
	return n
