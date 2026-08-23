class_name Bat
extends Node2D

## Patrols the air on a lazy sine, which is what makes it different from a
## slime: it owns the space above the floor rather than the floor itself.
## Landing on it squashes it, so it is a platform as much as a threat.

signal squashed(at: Vector2)

const SPEED := 30.0
const SPAN := 26.0               # pixels either side of where it spawned
const BOB := 9.0

var alive := true
var speed_scale := 1.0

var _sprite: Sprite2D
var _area: Area2D
var _origin := Vector2.ZERO
var _time := 0.0
var _direction := 1


func _ready() -> void:
	_origin = position
	_time = randf() * TAU

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("bat_a")
	add_child(_sprite)

	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(7, 5)
	shape.shape = rect
	_area.add_child(shape)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_time += delta
	_sprite.texture = PixelArt.tex("bat_a" if fmod(_time * 7.0, 2.0) < 1.0 else "bat_b")
	_sprite.flip_h = _direction < 0

	position.x += _direction * SPEED * speed_scale * delta
	if absf(position.x - _origin.x) > SPAN:
		position.x = _origin.x + signf(position.x - _origin.x) * SPAN
		_direction = -_direction
	# Whole pixels only, same rule the gem bob follows.
	position.y = _origin.y + roundf(sin(_time * 2.2 * speed_scale) * BOB)

	_check_player()


func _check_player() -> void:
	for body in _area.get_overlapping_bodies():
		if not (body is Player):
			continue
		var player := body as Player
		if not player.alive:
			continue
		var from_above := player.velocity.y > 20.0 and player.global_position.y < global_position.y - 2.0
		if from_above:
			player.stomp()
			die()
		else:
			player.kill()
		return


func die() -> void:
	if not alive:
		return
	alive = false
	squashed.emit(global_position)
	_area.set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(_sprite, "position:y", 8.0, 0.2)
	tween.tween_callback(queue_free)
