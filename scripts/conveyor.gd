class_name Conveyor
extends Node2D

## Moving ground that pushes the player horizontal ly in one direction.
## Painted on story rooms as ">" (right) or "<" (left) tiles.

const TILE := 8.0

var direction := 1          # 1 for right (>), -1 for left (<)
var width := 0.0            # pixels
var height := TILE

var _area: Area2D


func _ready() -> void:
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	add_child(_area)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	shape.position = Vector2(width * 0.5, height * 0.5)
	_area.add_child(shape)

	var sprite := Sprite2D.new()
	sprite.texture = _bake_sprite()
	add_child(sprite)


func setup(dir: int, w: float) -> void:
	direction = dir
	width = w


## Bake the sprite of moving tiles with animated arrows.
func _bake_sprite() -> ImageTexture:
	var w := int(width)
	var h := int(height)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Palette.OUTLINE)

	# Simple alternating pattern for direction indicator
	var ch := ">" if direction > 0 else "<"
	var frames := 2
	var pixels_per_frame := (w / frames) if w > 0 else 1
	var alt := randi() % frames

	for y in h:
		for x in w:
			if (x / pixels_per_frame) % 2 == alt:
				img.set_pixel(x, y, Palette.CYAN_MID)
			else:
				img.set_pixel(x, y, Palette.CYAN_DARK)

	return ImageTexture.create_from_image(img)


func _physics_process(_delta: float) -> void:
	for body in _area.get_overlapping_bodies():
		if body is Player and (body as Player).is_on_floor():
			(body as Player).push(Vector2(direction * Player.CONVEYOR_PUSH * 6.0, 0.0))
