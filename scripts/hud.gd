class_name Hud
extends Node2D

## The 14 pixel strip above the room: which room, how long, how many gems.
## It also fades in the room's hint for the first few seconds.

const SCREEN := Vector2(480, 270)
const BAND := 14.0
const HINT_HOLD := 4.5
const HINT_FADE := 1.2

var level: Level
var level_index := 0
var level_name := ""
var hint := ""

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, SCREEN.x, BAND), Palette.BG)
	draw_rect(Rect2(0, BAND - 1, SCREEN.x, 1), Palette.FRAME)

	PixelFont.draw_text(self, "%02d" % (level_index + 1), Vector2(6, 4), Palette.CYAN, 1)
	PixelFont.draw_text(self, Lang.t(level_name), Vector2(24, 4), Palette.GREY, 1)

	if level != null:
		var clock := Util.format_time(level.time)
		var size := PixelFont.measure(clock, 1)
		PixelFont.draw_text(self, clock, Vector2(roundf(SCREEN.x * 0.5 - size.x * 0.5), 4),
			Palette.WHITE, 1)

		var gems := Lang.tf("hud.gems", [level.gems_taken, level.gems_total])
		var complete := level.gems_total > 0 and level.gems_taken >= level.gems_total
		var gsize := PixelFont.measure(gems, 1)
		PixelFont.draw_text(self, gems, Vector2(SCREEN.x - 8.0 - gsize.x, 4),
			Palette.GOLD if complete else Palette.GREY, 1)

		var deaths := "X%d" % level.deaths
		var dsize := PixelFont.measure(deaths, 1)
		PixelFont.draw_text(self, deaths,
			Vector2(SCREEN.x - 16.0 - gsize.x - dsize.x, 4), Palette.MAGENTA_DARK, 1)

	_draw_hint()


func _draw_hint() -> void:
	if hint.is_empty() or _time > HINT_HOLD + HINT_FADE:
		return
	# The pause menu owns the middle of the screen while it is up.
	if get_tree().paused:
		return
	var color := Palette.GREY_DARK
	if _time > HINT_HOLD:
		# Two-step fade: pixel art has no business with smooth alpha ramps.
		color = Palette.FRAME
	PixelFont.draw_text_centered(self, Lang.t(hint), SCREEN.x * 0.5, BAND + 10.0, color, 1)
