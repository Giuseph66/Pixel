class_name Conveyor
extends Node2D

## The arrows on a run of belt tiles.
##
## The push itself lives in the player, which reads the tile under its feet the
## same way it reads ice — a belt is terrain, not a force. This node exists so
## the direction is visible and obviously moving; without the animation the
## tile is a grey slab that mysteriously carries you.

const TILE := 8
const FRAMES := 4              # one pixel of travel apart, looping every 4px
const PATTERN := 4.0           # chevron period, in pixels
const SCROLL_SCALE := 0.5      # of the push speed; full rate reads as a blur

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
	_sprite.texture = _bake(_frame_name(0))
	add_child(_sprite)


func _process(delta: float) -> void:
	_time += delta
	# Four frames a pixel apart, stepped off the push speed so the band always
	# runs the way it carries you. Scaled down because chevrons only four
	# pixels apart flicker rather than travel at the full 55 px/s.
	var travelled := _time * Player.CONVEYOR_PUSH * SCROLL_SCALE
	var phase := int(fmod(travelled, PATTERN))
	_sprite.texture = _bake(_frame_name(phase))


func _frame_name(phase: int) -> String:
	return "belt_%d" % (phase % FRAMES)


## One tile of art repeated across the run. Cached by PixelArt per frame name
## and length, so the four strips are baked once for the whole room.
func _bake(frame: String) -> ImageTexture:
	var key := "%s_x%d" % [frame, length]
	if PixelArt.has_cached(key):
		return PixelArt.cached(key)

	var tile := PixelArt.tex(frame).get_image()
	var img := Image.create_empty(length * TILE, TILE, false, Image.FORMAT_RGBA8)
	for i in length:
		img.blit_rect(tile, Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
	return PixelArt.store(key, ImageTexture.create_from_image(img))
