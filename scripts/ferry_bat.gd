class_name FerryBat
extends AnimatableBody2D

## A moving platform with a deadline. sync_to_physics carries whoever stands
## on it the same free way MovingPlatform does; the difference is it only
## lasts CARRY_TIME once someone boards, then it trembles and dives out from
## under them. The sides and underside stay lethal throughout — only the top
## is ever a ride, which is what keeps it a creature rather than a slab.

signal dived

const SPEED := 26.0
const SPAN := 48.0       # generous fixed reach — wide enough for the gaps the
                         # campaign builds it into, without the extra work of
                         # measuring the room the way MovingPlatform does
const BOB := 6.0
const CARRY_TIME := 3.2
const WARN_TIME := 0.8
const DIVE_SPEED := 210.0
const DIVE_DISTANCE := 240.0

enum State { PATROL, DIVE }

var speed_scale := 1.0
## Set by Level, the same way Lava and Slime learn who is in the room —
## boarding is judged against every player, not just one.
var players: Array[Player] = []

var _state := State.PATROL
var _origin := Vector2.ZERO
var _time := 0.0
var _direction := 1
var _carrying := false
var _carry := CARRY_TIME
var _sprite: Sprite2D
var _mortal: Area2D


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 2
	collision_mask = 0
	_origin = position
	_time = randf() * TAU

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("ferry_a")
	add_child(_sprite)

	var top := CollisionShape2D.new()
	var top_rect := RectangleShape2D.new()
	top_rect.size = Vector2(14, 3)
	top.shape = top_rect
	top.position = Vector2(0, -3)
	add_child(top)

	# Left with a gap under the riding surface: a body pressed flush against
	# the top shape overlaps the mortal one on the very frame it lands,
	# otherwise, and that reads as the platform killing you for landing on it.
	_mortal = Area2D.new()
	_mortal.collision_layer = 0
	_mortal.collision_mask = 1
	var side_shape := CollisionShape2D.new()
	var side_rect := RectangleShape2D.new()
	side_rect.size = Vector2(14, 6)
	side_shape.shape = side_rect
	side_shape.position = Vector2(0, 1)
	_mortal.add_child(side_shape)
	add_child(_mortal)
	_mortal.body_entered.connect(_on_touched)


func _physics_process(delta: float) -> void:
	match _state:
		State.PATROL:
			_time += delta
			_sprite.texture = PixelArt.tex("ferry_a" if fmod(_time * 7.0, 2.0) < 1.0 else "ferry_b")
			_sprite.flip_h = _direction < 0
			position.x += _direction * SPEED * speed_scale * delta
			if absf(position.x - _origin.x) > SPAN:
				position.x = _origin.x + signf(position.x - _origin.x) * SPAN
				_direction = -_direction
			position.y = _origin.y + roundf(sin(_time * 2.0 * speed_scale) * BOB)

			_check_carry(delta)
			_sprite.modulate = Color.WHITE
			if _carrying and _carry <= WARN_TIME:
				_sprite.modulate = Color.WHITE if fmod(_time, 0.14) < 0.07 else Color(1, 1, 1, 0.4)
		State.DIVE:
			position.y += DIVE_SPEED * delta
			if position.y - _origin.y > DIVE_DISTANCE:
				queue_free()


## Boarding starts the clock; it keeps running even if they step back off —
## a ferry that resets its schedule every time a passenger shifts their feet
## is not a deadline, it is a suggestion.
func _check_carry(delta: float) -> void:
	if not _carrying:
		for player: Player in players:
			if not player.alive:
				continue
			var collision := player.get_last_slide_collision()
			if collision != null and collision.get_collider() == self:
				_carrying = true
				_carry = CARRY_TIME
				break
	if not _carrying:
		return
	_carry -= delta * speed_scale
	if _carry <= 0.0:
		_dive()


func _dive() -> void:
	if _state == State.DIVE:
		return
	_state = State.DIVE
	_sprite.texture = PixelArt.tex("ferry_dive")
	_sprite.modulate = Color.WHITE
	# The body vanishes from under whoever was riding it — collision_layer 0
	# drops it out of sync_to_physics support the instant this runs, so the
	# player's own gravity picks them up rather than free-falling pinned to it.
	set_deferred("collision_layer", 0)
	_mortal.set_deferred("monitoring", false)
	dived.emit()


func _on_touched(body: Node2D) -> void:
	if body is Player and (body as Player).alive:
		(body as Player).kill()


func network_state() -> Dictionary:
	return {
		"state": _state,
		"time": _time,
		"direction": _direction,
		"carrying": _carrying,
		"carry": _carry,
	}


func apply_network_state(state: Dictionary) -> void:
	_state = int(state.get("state", _state))
	_time = float(state.get("time", _time))
	_direction = int(state.get("direction", _direction))
	_carrying = bool(state.get("carrying", _carrying))
	_carry = float(state.get("carry", _carry))
	_sprite.flip_h = _direction < 0
	if _state == State.DIVE:
		_sprite.texture = PixelArt.tex("ferry_dive")
		collision_layer = 0
		_mortal.set_deferred("monitoring", false)
	else:
		_sprite.texture = PixelArt.tex("ferry_a" if fmod(_time * 7.0, 2.0) < 1.0 else "ferry_b")
		collision_layer = 2
		_mortal.set_deferred("monitoring", true)
