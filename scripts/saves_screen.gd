class_name SavesScreen
extends Node2D

## Three runs, side by side, each with its own totals.
##
## Clearing a slot is how you replay the campaign with the abilities locked
## again. It only ever clears the one you are pointing at, which is why the
## screen shows all three at once: you can see what you are not touching.

signal picked(slot: int)
signal cancelled

const SCREEN := Vector2(480, 270)
const CARD := Vector2(140, 132)
const GAP := 12.0
const ORIGIN := Vector2(22, 54)

var cursor := 0
var _confirming := false
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cursor = Save.active


func _process(delta: float) -> void:
	_time += delta
	_handle_input()
	queue_redraw()


func _handle_input() -> void:
	if _confirming:
		if Input.is_action_just_pressed("p_accept"):
			Audio.play("menu_select")
			Save.reset_slot(cursor)
			Save.use_slot(cursor)
			_confirming = false
			picked.emit(cursor)
		elif Input.is_action_just_pressed("p_cancel"):
			Audio.play("menu_back")
			_confirming = false
		return

	if Input.is_action_just_pressed("p_right"):
		cursor = wrapi(cursor + 1, 0, Save.SLOTS)
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_left"):
		cursor = wrapi(cursor - 1, 0, Save.SLOTS)
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_accept"):
		Audio.play("menu_select")
		Save.use_slot(cursor)
		picked.emit(cursor)
	elif Input.is_action_just_pressed("p_restart"):
		# R, the same key that restarts a room, asks to clear a slot.
		Audio.play("menu_move")
		_confirming = true
	elif Input.is_action_just_pressed("p_cancel"):
		Audio.play("menu_back")
		cancelled.emit()


# -------------------------------------------------------------------- draw ---

func _draw() -> void:
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Palette.BG)
	PixelFont.draw_text_centered_shadow(self, Lang.t("saves.title"), SCREEN.x * 0.5, 20.0,
		Palette.WHITE, Palette.MAGENTA_DARK, 2)

	for i in Save.SLOTS:
		_draw_slot(i)

	var footer := Lang.t("saves.confirm") if _confirming else Lang.t("saves.footer")
	PixelFont.draw_text_centered(self, footer, SCREEN.x * 0.5, SCREEN.y - 14.0,
		Palette.MAGENTA if _confirming else Palette.GREY_DARK, 1)


func _draw_slot(i: int) -> void:
	var rect := Rect2(ORIGIN + Vector2(i * (CARD.x + GAP), 0.0), CARD)
	var selected := i == cursor
	var slot: Dictionary = Save.slots[i]
	var empty := Save.slot_is_empty(i)

	var border := Palette.FRAME
	if selected:
		border = Palette.MAGENTA if fmod(_time, 0.8) < 0.4 else Palette.WHITE
	elif i == Save.active:
		border = Palette.CYAN_DARK
	Util.draw_panel(self, rect, Palette.BG_SOFT if not empty else Palette.BG, border)

	var pad := rect.position + Vector2(9, 9)
	PixelFont.draw_text(self, Lang.tf("saves.slot", [i + 1]), pad,
		Palette.CYAN if not empty else Palette.GREY_DARK, 2)
	if i == Save.active:
		PixelFont.draw_text(self, Lang.t("saves.active"),
			rect.position + Vector2(rect.size.x - 32.0, 11.0), Palette.CYAN_DARK, 1)

	if empty:
		PixelFont.draw_text(self, Lang.t("saves.empty"), pad + Vector2(0, 40),
			Palette.GREY_DARK, 1)
		return

	var cleared := int((slot["cleared"] as Dictionary).size())
	_row(rect, 0, Lang.t("saves.rooms"), "%d/%d" % [cleared, Levels.count()])
	_row(rect, 1, Lang.t("saves.time"), Util.format_clock(float(slot["play_time"])))
	_row(rect, 2, Lang.t("saves.gems"), str(int(slot["gems_taken"])))
	_row(rect, 3, Lang.t("saves.endless"), str(int(slot["endless_best"])))
	_row(rect, 4, Lang.t("saves.deaths"), str(int(slot["total_deaths"])))
	_row(rect, 5, Lang.t("saves.codex"), "%d/%d" % [
		int((slot["codex"] as Dictionary).size()), Codex.count()])


func _row(rect: Rect2, i: int, label: String, value: String) -> void:
	var y := rect.position.y + 34.0 + i * 15.0
	PixelFont.draw_text(self, label, Vector2(rect.position.x + 9.0, y), Palette.GREY_DARK, 1)
	var size := PixelFont.measure(value, 1)
	PixelFont.draw_text(self, value,
		Vector2(rect.position.x + rect.size.x - 9.0 - size.x, y), Palette.WHITE, 1)
