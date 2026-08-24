class_name ElasticSlime
extends Node2D

## Slime that bounces the player instead of dying. Never dies from stomps.

const TILE := 8.0

var player: Player
var speed_scale := 1.0
var _sprite: Sprite2D
var _area: Area2D
var _position_x := 0.0
var _direction := 1
var _ground: Callable
var _wall: Callable
var _squash_time := 0.0

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
	add_child(_sprite)

	_position_x = position.x


func setup(g: Callable, w: Callable) -> void:
	_ground = g
	_wall = w


func _physics_process(delta: float) -> void:
	if _ground.call(floori(position.x / TILE), floori((position.y + TILE) / TILE)):
		# Walk
		var next_x := position.x + _direction * 34.0 * speed_scale * delta
		var test_x := floori(next_x / TILE)
		if not _wall.call(test_x, floori((position.y + TILE) / TILE)):
			_direction *= -1
		position.x = next_x
	else:
		# Fall
		position.y += 60.0 * delta

	_squash_time = maxf(_squash_time - delta, 0.0)
	var frame := "elastic_a" if _squash_time <= 0.0 else "elastic_b"
	_sprite.texture = PixelArt.tex(frame)

	# Check stomp
	for area in _area.get_overlapping_areas():
		if area.get_parent() is Player:
			var p := area.get_parent() as Player
			var py := p.global_position.y + Player.HEIGHT * 0.5
			if p.previous_bottom < py:
				p.spring_bounce()
				_squash_time = 0.1
