class_name Lava
extends Node2D

## A line that only ever goes up.
##
## Every other hazard in the game punishes a bad input. This one punishes
## standing still, which is a pressure the game otherwise has no way to apply.
## It rises at a constant rate and never accelerates: a room you can plan is the
## only kind worth hurrying through.

const RISE := 9.0               # px/s, about a tile and a bit per second
const MAX_SCALE := 2.2

var speed_scale := 1.0
var players: Array[Player] = []
## Set false once the room is won, so the tide cannot drown a finished run.
var running := true

var _surface := 0.0             # in this node's own space; smaller is higher
var _start := 0.0
var _time := 0.0


func setup(top_y: float) -> void:
	_surface = top_y
	_start = top_y


func _ready() -> void:
	z_index = 5
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not running:
		return

	_time += delta
	_surface -= RISE * minf(speed_scale, MAX_SCALE) * delta
	queue_redraw()

	for player: Player in players:
		if not is_instance_valid(player) or not player.alive or player.frozen:
			continue
		# Lava and player share the Level's local space. Comparing this against
		# global position counted the HUD offset as lava overlap.
		if player.position.y + Player.HEIGHT * 0.5 >= _surface:
			player.kill()


func stop() -> void:
	running = false


func _draw() -> void:
	var w := float(Levels.COLS * Level.TILE)
	var bottom := float(Levels.ROWS * Level.TILE)
	if _surface >= bottom:
		return

	draw_rect(Rect2(0.0, _surface, w, bottom - _surface), Palette.MAGENTA_DARK)

	# A travelling pixel crest makes the liquid read as hot and alive instead of
	# a flat red rectangle. All marks stay on the eight-pixel grid of the room.
	var phase := floori(_time * 10.0)
	for x in range(0, int(w), 4):
		var tile := x / 4
		var lift := -1.0 if posmod(tile + phase, 5) == 0 else 0.0
		draw_rect(Rect2(float(x), _surface + lift, 4.0, 2.0), Palette.MAGENTA)
		if posmod(tile + phase * 2, 7) == 0:
			draw_rect(Rect2(float(x + 1), _surface + lift, 2.0, 1.0), Palette.GOLD)

	# Small bright bubbles drift toward the crest, then reappear deeper below.
	for i in range(10):
		var bubble_y := _surface + 4.0 + float(posmod(i * 11 - phase, 18))
		var bubble_x := float(posmod(i * 47 + phase * 3, int(w)))
		draw_rect(Rect2(bubble_x, bubble_y, 1.0, 1.0), Palette.MAGENTA)
		if posmod(i + phase, 4) == 0:
			draw_rect(Rect2(bubble_x + 1.0, bubble_y + 1.0, 1.0, 1.0), Palette.GOLD)
