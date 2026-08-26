class_name Clone
extends AnimatableBody2D

## Step 24 — clone fantasma. Replays a recorded position trace exactly, frame
## for frame, rather than replaying inputs: a position is literal and always
## reproduces the same way, where replaying inputs would desync the moment a
## moving platform's phase differed from the day it was recorded.
##
## Solid on top only, same as a one-way platform (moving_platform.gd), so
## walking into the space the clone currently occupies never traps the
## player — the clone owns being an obstacle standing still, never a wall
## closing in.

const RECORD_HZ := 60
const MOVE_EPSILON := 0.15   # px/frame — under this, the trace reads as standing

var frames: PackedVector2Array = PackedVector2Array()
var _at := 0
var _sprite: Sprite2D
var _anim := 0.0


func setup(recorded: PackedVector2Array) -> void:
	frames = recorded


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 2
	collision_mask = 0

	if not frames.is_empty():
		global_position = frames[0]

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("player_idle")
	_sprite.modulate = Color(Palette.PURPLE.r, Palette.PURPLE.g, Palette.PURPLE.b, 0.6)
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(Player.WIDTH, Player.HEIGHT)
	shape.shape = rect
	shape.one_way_collision = true
	shape.one_way_collision_margin = 2.0
	add_child(shape)


func _physics_process(delta: float) -> void:
	if _at >= frames.size():
		queue_free()
		return
	var prev := global_position
	global_position = frames[_at]
	var dx := frames[_at].x - prev.x

	# A walk cycle, the same two frames and the same swap rate _update_sprite()
	# uses for the real player — without it the clone only ever shows
	# player_idle and a smooth glide with no animation reads as not moving at
	# all, screenshot or not.
	_anim += delta
	if absf(dx) > MOVE_EPSILON:
		_sprite.texture = PixelArt.tex("player_run_a" if fmod(_anim * 9.0, 2.0) < 1.0 else "player_run_b")
	else:
		_sprite.texture = PixelArt.tex("player_idle")

	if dx < -MOVE_EPSILON:
		_sprite.flip_h = true
	elif dx > MOVE_EPSILON:
		_sprite.flip_h = false
	_at += 1
