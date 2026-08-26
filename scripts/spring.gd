class_name Spring
extends Area2D

## Launches the player far above a normal jump. Only fires when they are
## actually coming down onto it.

const COOLDOWN := 0.25

var _sprite: Sprite2D
var _cooldown := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("spring")
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 5)
	shape.shape = rect
	shape.position.y = 1.5
	add_child(shape)


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_sprite.texture = PixelArt.tex("spring")
		return

	for body in get_overlapping_bodies():
		if body is Player:
			var player := body as Player
			if player.velocity.y >= -10.0 and player.global_position.y < global_position.y:
				player.spring_bounce()
				_cooldown = COOLDOWN
				_sprite.texture = PixelArt.tex("spring_fired")
				break


func network_state() -> Dictionary:
	return {"spring_cooldown": _cooldown}


func apply_network_state(state: Dictionary) -> void:
	_cooldown = maxf(float(state.get("spring_cooldown", _cooldown)), 0.0)
	_sprite.texture = PixelArt.tex("spring_fired" if _cooldown > 0.0 else "spring")
