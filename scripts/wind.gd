class_name Wind
extends Area2D

## A column or band of moving air. It never stops a fall, only slows it —
## PUSH_UP sits well under GRAVITY_DOWN on purpose, so a current buys time
## rather than becoming a floor you can stand on. Horizontal wind is always a
## headwind (it pushes left): the game only ever asks you to make progress
## rightward, so one direction is enough to be an obstacle.

const PUSH_UP := 620.0
const PUSH_SIDE := 380.0
const PARTICLE_RATE := 8.0     # per tile of the run, per second

var direction := Vector2.UP
var tiles := 1
var fx: Fx

var _particle_t := 0.0


func setup(dir: Vector2, run_tiles: int) -> void:
	direction = dir
	tiles = maxi(run_tiles, 1)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var vertical := absf(direction.y) > 0.5
	rect.size = Vector2(8, tiles * 8) if vertical else Vector2(tiles * 8, 8)
	shape.shape = rect
	# The node sits at the run's top-left tile, same anchor Conveyor uses —
	# the shape is offset to cover from there rather than centred on it.
	shape.position = rect.size * 0.5
	add_child(shape)


func _physics_process(delta: float) -> void:
	var strength := PUSH_UP if absf(direction.y) > 0.5 else PUSH_SIDE
	for body in get_overlapping_bodies():
		if body is Player:
			(body as Player).push(direction * strength)

	if fx == null:
		return
	_particle_t += delta
	var interval := 1.0 / (PARTICLE_RATE * float(tiles))
	while _particle_t >= interval:
		_particle_t -= interval
		_emit_particle()


## A drifting mark every tile or so is what tells the eye this column is not
## dead air — without it the mechanic is invisible until it is too late to
## react, which is the one thing a fair hazard cannot be.
func _emit_particle() -> void:
	var vertical := absf(direction.y) > 0.5
	var size := Vector2(8, tiles * 8) if vertical else Vector2(tiles * 8, 8)
	var world := global_position + Vector2(randf() * size.x, randf() * size.y)
	fx.emit(fx.to_local(world), 1, Palette.CYAN_DARK, 30.0, direction, 0.4, 0.3, 60.0)
