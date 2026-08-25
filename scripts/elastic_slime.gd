class_name ElasticSlime
extends Node2D

## A slime you land on instead of landing through. Stomping it does not kill it:
## it throws you the way a spring does and carries on walking.
##
## That makes it the one enemy in the game that is also a route. The sides still
## kill — without that it would be a moving platform with a face, and the room
## would have nothing to say.
##
## It walks by reading the grid, and resolves contact by hand, for the reasons
## written at the top of slime.gd.

signal bounced(at: Vector2)

const SPEED := 22.0
const TILE := 8.0
const BOX := Vector2(7.0, 8.0)
const TOP_OFFSET := 4.0
const SQUASH := 0.16

var direction := -1
var speed_scale := 1.0
var players: Array[Player] = []
var is_wall: Callable
var is_ground: Callable

var _sprite: Sprite2D
var _time := 0.0
var _squash := 0.0
var _approached_from_above: Dictionary = {}


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("elastic_a")
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_time += delta
	_squash = maxf(_squash - delta, 0.0)
	_sprite.texture = PixelArt.tex("elastic_b" if _squash > 0.0 else "elastic_a")
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

	var delta_pos := player.global_position - global_position
	var touching := absf(delta_pos.x) < (Player.WIDTH + BOX.x) * 0.5 \
		and absf(delta_pos.y) < (Player.HEIGHT + BOX.y) * 0.5

	if not touching:
		var feet := player.global_position.y + Player.HEIGHT * 0.5
		_approached_from_above[player.peer_id] = feet <= global_position.y - TOP_OFFSET
		return

	if bool(_approached_from_above.get(player.peer_id, true)):
		# spring_bounce rather than stomp: no chain, and it lives. The chain is
		# the reward for a row of kills, and nothing died here.
		player.spring_bounce()
		bounced.emit(global_position)
		_squash = SQUASH
	else:
		player.kill()
