class_name ShieldEnemy
extends Node2D

## A walker with a plate on its head. Landing on it kills you; only a ground
## pound gets through.
##
## Stomping had quietly become the answer to everything that walks. This asks
## the question again — and gives the ground pound a job outside of breaking
## blocks, which is the only thing it was for until now.

signal squashed(at: Vector2)

const SPEED := 24.0
const TILE := 8.0
const BOX := Vector2(7.0, 8.0)
const TOP_OFFSET := 4.0

var direction := -1
var alive := true
var speed_scale := 1.0
var players: Array[Player] = []
var is_wall: Callable
var is_ground: Callable

var _sprite: Sprite2D
var _time := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("shield_a")
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_time += delta
	_sprite.texture = PixelArt.tex("shield_a" if fmod(_time * 5.0, 2.0) < 1.0 else "shield_b")
	_sprite.flip_h = direction > 0

	if is_wall.is_valid() and is_ground.is_valid():
		var tx := floori(position.x / TILE)
		var ty := floori(position.y / TILE)
		var ahead := tx + direction
		if is_wall.call(ahead, ty) or not is_ground.call(ahead, ty + 1):
			direction = -direction
		else:
			position.x += direction * SPEED * speed_scale * delta
	else:
		position.x += direction * SPEED * speed_scale * delta

	_check_players()


func _check_players() -> void:
	for player: Player in players:
		_check_player(player)


func _check_player(player: Player) -> void:
	if not is_instance_valid(player) or not player.alive or player.frozen:
		return
	if Session.is_active() and not player.locally_controlled:
		return

	var delta_pos := player.global_position - global_position
	var touching := absf(delta_pos.x) < (Player.WIDTH + BOX.x) * 0.5 \
		and absf(delta_pos.y) < (Player.HEIGHT + BOX.y) * 0.5
	if not touching:
		return

	# The pound test comes first. If the approach test went first, a pound that
	# arrived a pixel off centre would kill the player, and the move the whole
	# enemy exists to teach would look broken.
	if player.is_pounding():
		die()
	else:
		player.kill()


func die() -> void:
	if not alive:
		return
	alive = false
	squashed.emit(global_position)
	_sprite.scale = Vector2(1.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)


func network_state() -> Dictionary:
	return {"alive": alive, "direction": direction, "time": _time}


func apply_network_state(state: Dictionary) -> void:
	direction = int(state.get("direction", direction))
	_time = float(state.get("time", _time))
	if not bool(state.get("alive", alive)):
		apply_network_defeat()


func apply_network_defeat() -> void:
	if not alive:
		return
	alive = false
	_sprite.scale = Vector2(1.4, 0.4)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tween.tween_callback(queue_free)
