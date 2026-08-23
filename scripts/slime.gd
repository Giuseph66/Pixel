class_name Slime
extends Node2D

## Walks back and forth along whatever it was placed on. It reads the level
## grid directly instead of using physics, so it can never fall through a
## corner or jitter against a wall.

signal squashed(at: Vector2)

const SPEED := 26.0
const TILE := 8.0

var direction := -1
var alive := true
var is_solid: Callable          # func(tx: int, ty: int) -> bool, supplied by Level

var _sprite: Sprite2D
var _area: Area2D
var _time := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("slime_a")
	add_child(_sprite)

	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(7, 6)
	shape.shape = rect
	shape.position.y = 1.0
	_area.add_child(shape)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_time += delta
	_sprite.texture = PixelArt.tex("slime_a" if fmod(_time * 5.0, 2.0) < 1.0 else "slime_b")
	_sprite.flip_h = direction > 0

	if is_solid.is_valid():
		var tx := floori(position.x / TILE)
		var ty := floori(position.y / TILE)
		var ahead := tx + direction
		# Turn around at a wall or at the edge of the platform.
		if is_solid.call(ahead, ty) or not is_solid.call(ahead, ty + 1):
			direction = -direction
		else:
			position.x += direction * SPEED * delta
	else:
		position.x += direction * SPEED * delta

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
	_sprite.texture = PixelArt.tex("slime_b")
	_sprite.scale = Vector2(1.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)
