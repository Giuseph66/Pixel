class_name GhostBlock
extends StaticBody2D

## Step 21 — ghost blocks. Solidity depends on whether the player is pressing
## anything, not a clock or a switch — and not raw speed either: reading
## velocity meant falling off a ledge or getting thrown by a spring counted as
## "moving" whether the player asked for it or not. 'h' is solid while nobody
## is holding a key and vanishes the instant someone is; 'H' is the opposite.
## Runs of tiles are one strip node, the same aggregation _spawn_conveyors()
## and _spawn_platforms() already do — a six-tile run is one node, not six.
##
## Never solidifies on top of someone already standing inside it — it waits
## for them to leave instead. That is more permissive than a step-12 gate
## (which kills on close), and the right call here: the cause is continuous
## motion, not one telegraphed event a player could be expected to already be
## clear of.
##
## Deliberately not wired into is_wall_or_gate(): nothing that patrols a floor
## (Slime, Saw, ElasticSlime, ShieldEnemy) is built to share one with a rule
## that can flip several times a second.

const TILE := 8.0
const COMMIT_TIME := 0.15   # the read has to hold before the state actually flips
const FADE := 0.1           # seconds — a cut reads as a glitch, not a rule

var inverted := false        # false = 'h', solid while still; true = 'H'
var length := 1
var players: Array[Player] = []

var _solid := true
var _moving := false        # committed state — this, not the raw read, decides solidity
var _commit_t := 0.0
var _sprite: Sprite2D
var _shape: CollisionShape2D


func setup(starts_inverted: bool, tiles: int = 1) -> void:
	inverted = starts_inverted
	length = maxi(tiles, 1)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0

	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _bake("ghost_H" if inverted else "ghost_h")
	add_child(_sprite)

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE * length, TILE)
	_shape.position = Vector2(TILE * length * 0.5, TILE * 0.5)
	_shape.shape = rect
	add_child(_shape)

	_apply(true, true)


func _physics_process(delta: float) -> void:
	var raw_moving := _any_player_pressing_input()

	# The read has to hold steady for COMMIT_TIME before it actually changes
	# the block's state. Without this, tapping a key for two frames on the
	# way past was enough to make an 'h' block vanish under a foot that was
	# really just passing through — the state changed faster than the player
	# could react to having caused it.
	if raw_moving == _moving:
		_commit_t = 0.0
	else:
		_commit_t += delta
		if _commit_t >= COMMIT_TIME:
			_moving = raw_moving
			_commit_t = 0.0

	var wants_solid := _moving if inverted else not _moving
	if wants_solid == _solid:
		return
	# The guard only ever holds back the solid transition — turning solid
	# under someone already inside would stuff them into new geometry.
	# Turning intangible under them is the entire mechanic and always allowed.
	if wants_solid and _any_player_inside():
		return
	_apply(wants_solid)


## Whether the player is doing anything, not whether they currently have
## velocity — falling off a ledge or getting thrown by a spring is not a
## choice to move, and reading raw speed counted it as one anyway.
func _any_player_pressing_input() -> bool:
	for p: Player in players:
		if is_instance_valid(p) and p.alive and p.moving_input:
			return true
	return false


func _any_player_inside() -> bool:
	var half := Vector2(TILE * length, TILE) * 0.5
	var center := global_position + half
	for p: Player in players:
		if not is_instance_valid(p):
			continue
		var d := p.global_position - center
		if absf(d.x) < half.x + Player.WIDTH * 0.5 and absf(d.y) < half.y + Player.HEIGHT * 0.5:
			return true
	return false


func _apply(solid: bool, instant: bool = false) -> void:
	_solid = solid
	_shape.set_deferred("disabled", not solid)
	var target := 1.0 if solid else 0.4
	if instant:
		_sprite.modulate.a = target
		return
	var t := create_tween()
	t.tween_property(_sprite, "modulate:a", target, FADE)


func network_state() -> Dictionary:
	return {"solid": _solid, "moving": _moving}


func apply_network_state(state: Dictionary) -> void:
	_moving = bool(state.get("moving", _moving))
	var solid := bool(state.get("solid", _solid))
	if solid != _solid:
		_apply(solid, true)


## One tile of art repeated across the run, cached by PixelArt per frame and
## length — same trick Conveyor uses, for the same reason.
func _bake(frame: String) -> ImageTexture:
	var key := "%s_x%d" % [frame, length]
	if PixelArt.has_cached(key):
		return PixelArt.cached(key)
	var tile := PixelArt.tex(frame).get_image()
	var img := Image.create_empty(length * int(TILE), int(TILE), false, Image.FORMAT_RGBA8)
	for i in length:
		img.blit_rect(tile, Rect2i(0, 0, int(TILE), int(TILE)), Vector2i(i * int(TILE), 0))
	return PixelArt.store(key, ImageTexture.create_from_image(img))
