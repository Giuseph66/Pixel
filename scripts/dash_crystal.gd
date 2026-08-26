class_name DashCrystal
extends Area2D

## Gives the dash back in mid-air, then goes dim and recharges. It is what
## turns a dash from one move into a route: a line of these is a sentence.

const RECHARGE := 1.6

signal activated(at: Vector2)

var _sprite: Sprite2D
var _time := 0.0
var _cooldown := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_time = randf() * TAU

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("crystal")
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)


func _process(delta: float) -> void:
	_time += delta
	# Same whole-pixel bob the gems use, so the two read as one family.
	_sprite.position.y = roundf(sin(_time * 3.0) * 1.5)

	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_sprite.texture = PixelArt.tex("crystal")
		return

	for body in get_overlapping_bodies():
		if not (body is Player):
			continue
		var player := body as Player
		if not player.alive or player.has_dash:
			continue
		if Session.is_active() and not player.locally_controlled:
			continue
		player.refill_dash()
		network_activate()
		Audio.play("crystal")
		activated.emit(global_position)
		break


func network_state() -> Dictionary:
	return {"crystal_cooldown": _cooldown}


func apply_network_state(state: Dictionary) -> void:
	_cooldown = maxf(float(state.get("crystal_cooldown", _cooldown)), 0.0)
	_sprite.texture = PixelArt.tex("crystal_used" if _cooldown > 0.0 else "crystal")


func network_activate() -> void:
	_cooldown = RECHARGE
	_sprite.texture = PixelArt.tex("crystal_used")
