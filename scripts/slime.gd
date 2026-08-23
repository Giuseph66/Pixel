class_name Slime
extends Node2D

## Walks back and forth along whatever it was placed on. It reads the level
## grid directly instead of using physics, so it can never fall through a
## corner or jitter against a wall.
##
## Contact with the player is also resolved by hand rather than with an Area2D.
## An area reports an overlap a frame or two after it happens, and this slime is
## eight pixels tall: a full-speed fall crosses it in one frame, so by the time
## an area got around to saying "touching" the player had already landed and
## every clue about where they came from was gone. Sampling the player directly,
## every physics frame, means the approach is never in doubt.

signal squashed(at: Vector2)

const SPEED := 26.0
const TILE := 8.0
const BOX := Vector2(7.0, 8.0)  # hit box, matching the sprite
const TOP_OFFSET := 4.0         # sprite is 8px tall and centred on the node

var direction := -1
var alive := true
## Endless mode winds this up with depth once rooms cannot hold more threat.
var speed_scale := 1.0
var player: Player              # handed over by Level once it exists
var is_wall: Callable           # func(tx: int, ty: int) -> bool, supplied by Level
var is_ground: Callable         # same shape, but one-way slabs count as ground

var _sprite: Sprite2D
var _time := 0.0
## Whether the player's feet were clear of the slime's head on the last frame
## they were not yet touching it. This is the entire stomp test.
var _approached_from_above := true


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("slime_a")
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_time += delta
	_sprite.texture = PixelArt.tex("slime_a" if fmod(_time * 5.0, 2.0) < 1.0 else "slime_b")
	_sprite.flip_h = direction > 0

	if is_wall.is_valid() and is_ground.is_valid():
		var tx := floori(position.x / TILE)
		var ty := floori(position.y / TILE)
		var ahead := tx + direction
		# Turn around at a wall or at the edge of the platform. Walls and floors
		# are different questions: a one-way slab is something to stand on but
		# never something to bump into.
		if is_wall.call(ahead, ty) or not is_ground.call(ahead, ty + 1):
			direction = -direction
		else:
			position.x += direction * SPEED * speed_scale * delta
	else:
		position.x += direction * SPEED * speed_scale * delta

	_check_player()


func _check_player() -> void:
	if player == null or not player.alive or player.frozen:
		return

	var delta_pos := player.global_position - global_position
	var touching := absf(delta_pos.x) < (Player.WIDTH + BOX.x) * 0.5 \
		and absf(delta_pos.y) < (Player.HEIGHT + BOX.y) * 0.5

	if not touching:
		# Remember the approach while there is still an approach to remember.
		var feet := player.global_position.y + Player.HEIGHT * 0.5
		_approached_from_above = feet <= global_position.y - TOP_OFFSET
		return

	if _approached_from_above:
		player.stomp()
		die()
	else:
		player.kill()


func die() -> void:
	if not alive:
		return
	alive = false
	squashed.emit(global_position)
	_sprite.texture = PixelArt.tex("slime_b")
	_sprite.scale = Vector2(1.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)
