class_name MovingPlatform
extends AnimatableBody2D

## A slab that carries the player. `sync_to_physics` is what does the carrying:
## Godot moves a CharacterBody2D standing on an AnimatableBody2D for free, so
## there is no riding logic here.
##
## The travel is not authored per platform. It is measured from the level grid
## at spawn — the slab walks outwards until it would touch something, up to
## MAX_TRAVEL — which means a level designer drops the tiles and the platform
## works out how far it can go.

const TILE := 8
const MAX_TRAVEL := 7           # tiles, each direction
const SPEED := 34.0

var length := 1                 # in tiles
var vertical := false
var speed_scale := 1.0

var _origin := Vector2.ZERO
var _reach_low := 0.0           # pixels it may travel towards -x / -y
var _reach_high := 0.0
var _direction := 1.0
var _sprite: Sprite2D


## Called before the platform enters the tree. `free_at` answers "is this grid
## cell empty air?" so the platform can measure its own runway.
func setup(tiles: int, is_vertical: bool, tx: int, ty: int, free_at: Callable) -> void:
	length = maxi(tiles, 1)
	vertical = is_vertical

	var low := 0
	var high := 0
	if vertical:
		while low < MAX_TRAVEL and _row_free(free_at, tx, ty - low - 1, length):
			low += 1
		while high < MAX_TRAVEL and _row_free(free_at, tx, ty + high + 1, length):
			high += 1
	else:
		while low < MAX_TRAVEL and free_at.call(tx - low - 1, ty):
			low += 1
		while high < MAX_TRAVEL and free_at.call(tx + length + high, ty):
			high += 1

	_reach_low = float(low) * TILE
	_reach_high = float(high) * TILE


static func _row_free(free_at: Callable, tx: int, ty: int, tiles: int) -> bool:
	for i in tiles:
		if not free_at.call(tx + i, ty):
			return false
	return true


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 2
	collision_mask = 0
	_origin = position

	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _bake()
	_sprite.position = Vector2(-TILE * 0.5, -TILE * 0.5)
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length * TILE, TILE)
	shape.shape = rect
	shape.position = Vector2((length - 1) * TILE * 0.5, 0.0)
	add_child(shape)

	# A platform pinned between two walls would judder in place; park it.
	if _reach_low <= 0.0 and _reach_high <= 0.0:
		set_physics_process(false)


func _bake() -> ImageTexture:
	var img := Image.create_empty(length * TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in length:
		PixelArt.paint_platform(img, i, 0)
	return ImageTexture.create_from_image(img)


func _physics_process(delta: float) -> void:
	var step := _direction * SPEED * speed_scale * delta
	var offset := 0.0
	if vertical:
		offset = position.y - _origin.y + step
	else:
		offset = position.x - _origin.x + step

	if offset > _reach_high:
		offset = _reach_high
		_direction = -1.0
	elif offset < -_reach_low:
		offset = -_reach_low
		_direction = 1.0

	# Whole pixels only: a platform on a fractional offset shimmers against the
	# terrain behind it.
	if vertical:
		position.y = _origin.y + offset
	else:
		position.x = _origin.x + offset
