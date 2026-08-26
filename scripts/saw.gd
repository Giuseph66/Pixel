class_name Saw
extends Node2D

## Runs along the ground it was placed on and kills from every side — there is
## no stomping a blade. It reads the level grid the same way a slime does, so it
## turns at walls and at the edge of its platform instead of falling off.
##
## Segments pen it in between two posts: the threat is crossing the pen, not
## being chased across the room.

const SPEED := 52.0
const TILE := 8.0

var direction := -1
var speed_scale := 1.0
var is_wall: Callable            # func(tx: int, ty: int) -> bool
var is_ground: Callable          # func(tx: int, ty: int) -> bool

var _sprite: Sprite2D
var _area: Area2D
var _time := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("saw_a")
	add_child(_sprite)

	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	_area.add_child(shape)
	add_child(_area)


func _physics_process(delta: float) -> void:
	_time += delta
	# Two frames swapped fast reads as a spin; rotating the sprite would smear
	# the pixel grid.
	_sprite.texture = PixelArt.tex("saw_a" if fmod(_time * 14.0, 2.0) < 1.0 else "saw_b")

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

	for body in _area.get_overlapping_bodies():
		if body is Player and (body as Player).alive:
			var player := body as Player
			if Session.is_active() and not player.locally_controlled:
				continue
			player.kill()
			return


func network_state() -> Dictionary:
	return {"direction": direction, "time": _time}


func apply_network_state(state: Dictionary) -> void:
	direction = int(state.get("direction", direction))
	_time = float(state.get("time", _time))
