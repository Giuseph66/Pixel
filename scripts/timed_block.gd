class_name TimedBlock
extends Node2D

## Ground that keeps a beat. Solid for a while, gone for a while, and it warns
## before it goes — the difficulty is reading the rhythm, never reacting to a
## surprise.
##
## Two variants share one clock so a level can alternate them and build a path
## that assembles itself under the player: 't' starts solid, 'T' starts open.

const PERIOD := 1.15
const WARN := 0.3

var inverted := false
var speed_scale := 1.0

var _sprite: Sprite2D
var _body: StaticBody2D
var _shape: CollisionShape2D
var _time := 0.0
var _solid := true


func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)

	_body = StaticBody2D.new()
	_body.collision_layer = 2
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 8)
	_shape.shape = rect
	_body.add_child(_shape)
	add_child(_body)

	_time = PERIOD if inverted else 0.0
	_apply(true)


func _physics_process(delta: float) -> void:
	_time += delta * speed_scale
	var solid := fmod(_time, PERIOD * 2.0) < PERIOD
	if solid != _solid:
		_apply(solid)
		return

	# Blink through the last moments of being solid.
	if _solid:
		var left := PERIOD - fmod(_time, PERIOD * 2.0)
		if left < WARN:
			_sprite.visible = fmod(_time * 18.0, 2.0) < 1.0


func _apply(solid: bool) -> void:
	_solid = solid
	_sprite.visible = true
	_sprite.texture = PixelArt.tex("timed_on" if solid else "timed_off")
	_shape.set_deferred("disabled", not solid)
