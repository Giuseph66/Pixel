class_name Transition
extends Node2D

## Screen wipe made of vertical bars: even bars grow down, odd bars grow up.
## It is drawn in whole pixels, so it reads as part of the art rather than as
## a fade sitting on top of it.

const SCREEN := Vector2(480, 270)
const BARS := 24
const DURATION := 0.26

var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	progress = 0.0


func cover() -> void:
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, DURATION).set_trans(Tween.TRANS_CUBIC)
	await tween.finished


func reveal() -> void:
	var tween := create_tween()
	tween.tween_property(self, "progress", 0.0, DURATION).set_trans(Tween.TRANS_CUBIC)
	await tween.finished


func _draw() -> void:
	if progress <= 0.0:
		return
	var bar_w := SCREEN.x / float(BARS)
	for i in BARS:
		# Stagger the bars a little so the wipe has a diagonal feel.
		var delay := float(i % 4) * 0.06
		var local := clampf((progress - delay) / maxf(1.0 - delay, 0.01), 0.0, 1.0)
		var h := roundf(SCREEN.y * local)
		if h <= 0.0:
			continue
		var x := roundf(i * bar_w)
		var w := roundf((i + 1) * bar_w) - x
		if i % 2 == 0:
			draw_rect(Rect2(x, 0, w, h), Palette.BG)
		else:
			draw_rect(Rect2(x, SCREEN.y - h, w, h), Palette.BG)
