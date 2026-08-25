class_name PlaySelectScreen
extends Node2D

## The choice JOGAR opens: STORY, ENDLESS, SANDBOX. Panels side by side rather
## than a vertical list because the three modes are genuinely parallel choices,
## not steps in a hierarchy — a stacked list would imply an order that is not
## there.

signal chosen(id: String)
signal cancelled

const SCREEN := Vector2(480, 270)
const PANEL := Vector2(148, 168)
const GAP := 10.0
const PANELS := 3
const IDS := ["story", "endless", "sandbox"]

var cursor := 0                 # 0 = story, 1 = endless, 2 = sandbox
var _cube: Texture2D
var _infinity: Texture2D
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cube = PixelArt.cube(8)
	_infinity = PixelArt.infinity_icon()


func _process(delta: float) -> void:
	_time += delta
	_handle_input()
	queue_redraw()


func _handle_input() -> void:
	if Input.is_action_just_pressed("p_left"):
		cursor = wrapi(cursor - 1, 0, PANELS)
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_right"):
		cursor = wrapi(cursor + 1, 0, PANELS)
		Audio.play("menu_move")
	elif Input.is_action_just_pressed("p_accept"):
		Audio.play("menu_select")
		chosen.emit(IDS[cursor])
	elif Input.is_action_just_pressed("p_cancel"):
		Audio.play("menu_back")
		cancelled.emit()


func _panel_rect(i: int) -> Rect2:
	var total_w := PANEL.x * PANELS + GAP * (PANELS - 1)
	var left := roundf((SCREEN.x - total_w) * 0.5)
	var top := roundf((SCREEN.y - PANEL.y) * 0.5) + 8.0
	return Rect2(left + i * (PANEL.x + GAP), top, PANEL.x, PANEL.y)


# -------------------------------------------------------------------- draw ---

func _draw() -> void:
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Palette.BG)

	PixelFont.draw_text_centered_shadow(self, Lang.t("play.title"), SCREEN.x * 0.5, 20.0,
		Palette.WHITE, Palette.MAGENTA_DARK, 2)

	_draw_story_panel(_panel_rect(0), cursor == 0)
	_draw_endless_panel(_panel_rect(1), cursor == 1)
	_draw_sandbox_panel(_panel_rect(2), cursor == 2)

	PixelFont.draw_text_centered(self, Lang.t("play.footer"),
		SCREEN.x * 0.5, SCREEN.y - 14.0, Palette.GREY_DARK, 1)


func _panel_border(selected: bool) -> Color:
	if not selected:
		return Palette.FRAME
	return Palette.MAGENTA if fmod(_time, 0.8) < 0.4 else Palette.WHITE


func _draw_story_panel(rect: Rect2, selected: bool) -> void:
	Util.draw_panel(self, rect, Palette.BG_SOFT, _panel_border(selected))
	var cx := rect.position.x + rect.size.x * 0.5

	var hover := roundf(sin(_time * 1.8) * 1.5)
	draw_texture(_cube, Vector2(roundf(cx - _cube.get_width() * 0.5),
		rect.position.y + 18.0 + hover))

	PixelFont.draw_text_centered(self, Lang.t("play.story"), cx, rect.position.y + 58.0,
		Palette.WHITE if selected else Palette.GREY, 2)

	var cleared := Save.cleared_count()
	var total := Levels.count()
	var y := rect.position.y + rect.size.y - 40.0
	if cleared <= 0:
		PixelFont.draw_text_centered(self, Lang.t("play.story_new"), cx, y, Palette.GREY_DARK, 1)
		return

	PixelFont.draw_text_centered(self, Lang.tf("play.story_progress", [cleared, total]),
		cx, y, Palette.CYAN if cleared >= total else Palette.GREY, 1)
	PixelFont.draw_text_centered(self, Lang.tf("play.story_gems", [Save.total_gems()]),
		cx, y + 12.0, Palette.GOLD, 1)

	_draw_bar(rect, float(cleared) / float(total))


func _draw_endless_panel(rect: Rect2, selected: bool) -> void:
	Util.draw_panel(self, rect, Palette.BG_SOFT, _panel_border(selected))
	var cx := rect.position.x + rect.size.x * 0.5

	var hover := roundf(sin(_time * 1.8 + PI) * 1.5)
	draw_texture(_infinity, Vector2(roundf(cx - _infinity.get_width() * 0.5),
		rect.position.y + 24.0 + hover))

	PixelFont.draw_text_centered(self, Lang.t("play.endless"), cx, rect.position.y + 58.0,
		Palette.WHITE if selected else Palette.GREY, 2)

	var best := int(Save.data["endless_best"])
	var y := rect.position.y + rect.size.y - 40.0
	if best <= 0:
		PixelFont.draw_text_centered(self, Lang.t("play.endless_new"), cx, y, Palette.GREY_DARK, 1)
		return

	PixelFont.draw_text_centered(self, Lang.tf("play.endless_best", [best]),
		cx, y, Palette.PURPLE, 1)


func _draw_sandbox_panel(rect: Rect2, selected: bool) -> void:
	Util.draw_panel(self, rect, Palette.BG_SOFT, _panel_border(selected))
	var cx := rect.position.x + rect.size.x * 0.5

	var hover := roundf(sin(_time * 1.8 + PI * 0.5) * 1.5)
	_draw_editor_icon(Vector2(cx, rect.position.y + 32.0 + hover))

	PixelFont.draw_text_centered(self, Lang.t("play.sandbox"), cx, rect.position.y + 58.0,
		Palette.WHITE if selected else Palette.GREY, 2)

	var made := Sandbox.all().size()
	var y := rect.position.y + rect.size.y - 40.0
	if made <= 0:
		PixelFont.draw_text_centered(self, Lang.t("play.sandbox_new"), cx, y,
			Palette.GREY_DARK, 1)
		return
	PixelFont.draw_text_centered(self, Lang.tf("play.sandbox_made", [made]), cx, y,
		Palette.CYAN, 1)


## A three by three grid of tiles with one of them held under a cursor: the
## editor screen, shrunk to sixteen pixels. Drawn rather than a sprite grid
## because it is the only place in the game that needs it.
func _draw_editor_icon(center: Vector2) -> void:
	var cell := 5.0
	var origin := Vector2(roundf(center.x - cell * 1.5), roundf(center.y - cell * 1.5))
	for j in 3:
		for i in 3:
			var at := origin + Vector2(i * cell, j * cell)
			draw_rect(Rect2(at, Vector2(cell - 1, cell - 1)),
				Palette.CYAN_DARK if (i + j) % 2 == 0 else Palette.FRAME)
	var pick := Rect2(origin + Vector2(cell, cell), Vector2(cell - 1, cell - 1))
	draw_rect(pick, Palette.GOLD)
	Util.draw_panel(self, Rect2(pick.position - Vector2(1, 1), pick.size + Vector2(2, 2)),
		Color(0, 0, 0, 0), Palette.WHITE)


## Thin fill along a panel's bottom edge, echoing the room-select cards.
func _draw_bar(rect: Rect2, fraction: float) -> void:
	var pad := 14.0
	var width := rect.size.x - pad * 2
	var y := rect.position.y + rect.size.y - 12.0
	draw_rect(Rect2(rect.position.x + pad, y, width, 2), Palette.FRAME)
	var filled := roundf(width * clampf(fraction, 0.0, 1.0))
	if filled > 0.0:
		draw_rect(Rect2(rect.position.x + pad, y, filled, 2),
			Palette.GOLD if fraction >= 1.0 else Palette.CYAN_DARK)
