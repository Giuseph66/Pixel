class_name PhaseBlock
extends StaticBody2D

## Solid, except while a dash is in the air somewhere in the room. Level owns
## the question of whether anyone is currently dashing — a block only answers
## to set_solid(), the same shape every other switched block in this game
## takes.

var solid := true

var _shape: CollisionShape2D
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("phase_block")
	add_child(_sprite)

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 8)
	_shape.shape = rect
	add_child(_shape)

	set_solid(solid)


## Translucent while passable — the only feedback a player mid-dash has time
## to read, and the reason the phase turns on the instant the dash starts
## rather than waiting for the block to notice a collision.
func set_solid(value: bool) -> void:
	solid = value
	_shape.set_deferred("disabled", not value)
	_sprite.modulate = Color(1, 1, 1, 1.0 if value else 0.35)


func contains(pos: Vector2) -> bool:
	var half := Vector2(4, 4) + Vector2(Player.WIDTH, Player.HEIGHT) * 0.5
	var d := pos - global_position
	return absf(d.x) < half.x and absf(d.y) < half.y
