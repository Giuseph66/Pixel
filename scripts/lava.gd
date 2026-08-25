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
var player: Player
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

	if player == null or not player.alive or player.frozen:
		return
	if player.global_position.y + Player.HEIGHT * 0.5 >= _surface:
		player.kill()


func stop() -> void:
	running = false


func _draw() -> void:
	var w := float(Levels.COLS * Level.TILE)
	var bottom := float(Levels.ROWS * Level.TILE)
	if _surface >= bottom:
		return

	draw_rect(Rect2(0.0, _surface, w, bottom - _surface), Palette.MAGENTA_DARK)
	# Two bright lines on the crest, alternating: at a distance the movement is
	# the only thing that reads, and a flat slab of colour does not move.
	draw_rect(Rect2(0.0, _surface, w, 1.0), Palette.GOLD)
	if fmod(_time, 0.25) < 0.125:
		draw_rect(Rect2(0.0, _surface + 1.0, w, 1.0), Palette.WHITE)
