class_name Spike
extends Area2D

## Kills on touch. The hitbox is deliberately smaller than the tile so brushing
## the outer pixels while jumping past is forgiving.

var facing_down := false


func setup(down: bool) -> void:
	facing_down = down


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	var sprite := Sprite2D.new()
	sprite.texture = PixelArt.tex("spike")
	if facing_down:
		sprite.rotation = PI
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6, 4)
	shape.shape = rect
	shape.position.y = 2.0 if not facing_down else -2.0
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).kill()
