class_name Conveyor
extends Node2D

## The arrows on a run of belt tiles.
##
## The push itself lives in the player, which reads the tile under its feet the
## same way it reads ice — a belt is terrain, not a force. This node exists so
## the direction is visible and obviously moving; without the animation the
## tile is a grey slab that mysteriously carries you.

const TILE := 8
const FRAME_TIME := 0.09

var direction := 1              # 1 for '>', -1 for '<'
var length := 1                 # in tiles

var _sprite: Sprite2D
var _time := 0.0


func setup(dir: int, tiles: int) -> void:
	direction = dir
	length = maxi(tiles, 1)


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.flip_h = direction < 0
	_sprite.texture = _bake("belt_a")
	add_child(_sprite)


func _process(delta: float) -> void:
	_time += delta
	# Two frames, half a chevron apart, which reads as the band sliding.
	var frame := "belt_a" if fmod(_time, FRAME_TIME * 2.0) < FRAME_TIME else "belt_b"
	_sprite.texture = _bake(frame)


## One tile of art repeated across the run. Cached by PixelArt per frame name,
## so the two textures are built once for the whole room.
func _bake(frame: String) -> ImageTexture:
	var key := "%s_x%d" % [frame, length]
	if PixelArt.has_cached(key):
		return PixelArt.cached(key)

	var tile := PixelArt.tex(frame).get_image()
	var img := Image.create_empty(length * TILE, TILE, false, Image.FORMAT_RGBA8)
	for i in length:
		img.blit_rect(tile, Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
	return PixelArt.store(key, ImageTexture.create_from_image(img))
