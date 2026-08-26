class_name RecordPad
extends Area2D

## Step 24 — clone fantasma. Touching this starts Level's recording; the pad
## itself has nothing more to do after that; it frees itself so a second
## touch (from the clone that is about to walk back over it) can never
## restart a recording already in progress.

signal touched

var _fired := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	var sprite := Sprite2D.new()
	sprite.texture = PixelArt.tex("icon_clone")
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 8)
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _fired or not (body is Player):
		return
	_fired = true
	touched.emit()
