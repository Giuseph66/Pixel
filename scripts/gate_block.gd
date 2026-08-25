class_name GateBlock
extends StaticBody2D

## A one-tile wall that Level turns on and off. `inverted` is the difference
## between 'g' (starts solid) and 'G' (starts open) — the same switch drives
## both, which is what lets one press open one path and seal another.
##
## Never baked into the room's static terrain: is_solid() deliberately leaves
## g/G out for the same reason moving platforms are left out — a shape baked
## once cannot be switched later, and this one has to be.

const SIZE := 8.0

var inverted := false
var solid := true

var _shape: CollisionShape2D
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0

	_sprite = Sprite2D.new()
	add_child(_sprite)

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(SIZE, SIZE)
	_shape.shape = rect
	add_child(_shape)

	# `solid` may already carry the room's opening state, set by Level before
	# this entered the tree — set_solid() applies it to the shape as well as
	# the sprite, rather than trusting the shape's own default (enabled).
	set_solid(solid)


func compute_solid(switch_state: bool) -> bool:
	return switch_state != inverted


## Disabling a CollisionShape2D takes effect next physics step regardless, so
## there is no move_and_slide() mid-step to fight — set_deferred here is about
## not touching physics state from inside a physics callback, same rule every
## other toggled block in this game follows.
func set_solid(value: bool) -> void:
	solid = value
	_shape.set_deferred("disabled", not value)
	_paint(value)


func _paint(value: bool) -> void:
	_sprite.texture = PixelArt.tex("gate_solid" if value else "gate_open")


## Axis-aligned overlap against the player's own box. Checked synchronously,
## before the shape is even re-enabled, because the question ("did the gate
## just close on someone") has to be answered in the same frame it closes —
## waiting a physics frame for an Area2D would let the block resolve the
## overlap on its own first, in whatever direction move_and_slide() prefers.
func overlaps_player(player: Player) -> bool:
	var half := Vector2(SIZE, SIZE) * 0.5 + Vector2(Player.WIDTH, Player.HEIGHT) * 0.5
	var d := player.global_position - global_position
	return absf(d.x) < half.x and absf(d.y) < half.y
