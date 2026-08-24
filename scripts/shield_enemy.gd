class_name ShieldEnemy
extends Node2D

## Enemy with a shield on top. Dies only by ground pound, prensa, or spike push.

const TILE := 8.0

var player: Player
var speed_scale := 1.0
var _sprite: Sprite2D
var _area: Area2D
var _direction := 1
var _ground: Callable
var _wall: Callable

func _ready() -> void:
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	add_child(_area)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE, TILE)
	shape.shape = rect
	shape.position = Vector2(TILE * 0.5, TILE * 0.5)
	_area.add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = PixelArt.tex("shield_a")
	add_child(_sprite)


func setup(g: Callable, w: Callable) -> void:
	_ground = g
	_wall = w


func _physics_process(delta: float) -> void:
	if _ground.call(floori(position.x / TILE), floori((position.y + TILE) / TILE)):
		var next_x := position.x + _direction * 34.0 * speed_scale * delta
		var test_x := floori(next_x / TILE)
		if not _wall.call(test_x, floori((position.y + TILE) / TILE)):
			_direction *= -1
		position.x = next_x
	else:
		position.y += 60.0 * delta

	# Check pound
	for area in _area.get_overlapping_areas():
		if area.get_parent() is Player:
			var p := area.get_parent() as Player
			if p.is_pounding():
				die()
			else:
				p.kill()


func die() -> void:
	queue_free()
