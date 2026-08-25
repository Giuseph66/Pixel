class_name Laser
extends Node2D

## An emitter fixed to a wall, cycling sleep -> warn -> fire. The beam's reach
## is measured against the room's own solidity, so it stops at the first real
## wall the same way a wall stops the player.
##
## Intensity shortens SLEEP only. WARN and FIRE stay fixed no matter how deep
## the run — a laser whose warning shrinks with depth is not a harder laser,
## it is an unfair one, and 0.5s is already the floor this game is willing
## to ask a reaction to.

const SLEEP := 1.4
const WARN := 0.5
const FIRE := 0.6
const MAX_REACH_TILES := 60

var speed_scale := 1.0
var dir := Vector2.RIGHT
var is_solid_at: Callable

var _time := 0.0
var _phase := 0          # 0 sleep, 1 warn, 2 fire
var _frozen := 0.0       # step 12/16 — a switch can buy a safe window
var _reach := 8.0
var _sprite: Sprite2D
var _area: Area2D
var _shape: RectangleShape2D


func setup(direction: Vector2, solid_check: Callable) -> void:
	dir = direction
	is_solid_at = solid_check


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("laser_idle")
	add_child(_sprite)

	_shape = RectangleShape2D.new()
	var cs := CollisionShape2D.new()
	cs.shape = _shape
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	_area.monitoring = false
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)

	_measure()
	queue_redraw()


## Intensity compresses the wait, never the warning or the shot.
func _sleep_time() -> float:
	return SLEEP / maxf(speed_scale, 0.01)


## A switch elsewhere in the room bought this much safe time. Forces the
## laser back to idle immediately rather than letting it finish whatever shot
## was already in progress — a switch that promises safety and then lets the
## beam that was already firing keep firing would teach the wrong lesson.
func freeze(duration: float) -> void:
	_frozen = maxf(_frozen, duration)
	if _phase != 0:
		_phase = 0
		_time = 0.0
		_area.monitoring = false
		_sprite.texture = PixelArt.tex("laser_idle")
		queue_redraw()


func _physics_process(delta: float) -> void:
	if _frozen > 0.0:
		_frozen -= delta
		return
	var sleep := _sleep_time()
	var cycle := sleep + WARN + FIRE
	var before := _phase
	_time = fmod(_time + delta, cycle)

	if _time >= sleep + WARN:
		_phase = 2
	elif _time >= sleep:
		_phase = 1
	else:
		_phase = 0

	if _phase != before:
		match _phase:
			0:
				_area.monitoring = false
				_sprite.texture = PixelArt.tex("laser_idle")
			1:
				_sprite.texture = PixelArt.tex("laser_warn")
				Audio.play("laser_warn")
			2:
				# Terrain can change (a gate, a timed block) between one shot
				# and the next, so the reach is measured fresh every time
				# rather than trusted from the room's first frame.
				_measure()
				_update_shape()
				_area.monitoring = true
				_sprite.texture = PixelArt.tex("laser_fire")
				Audio.play("laser_fire")
				_check_overlap()
		queue_redraw()


func _measure() -> void:
	var tx := roundi(position.x / 8.0)
	var ty := roundi(position.y / 8.0)
	var steps := 0
	while steps < MAX_REACH_TILES:
		var nx := tx + int(dir.x) * (steps + 1)
		var ny := ty + int(dir.y) * (steps + 1)
		if is_solid_at.call(nx, ny):
			break
		steps += 1
	_reach = float(steps) * 8.0 + 4.0


func _update_shape() -> void:
	const THICK := 4.0
	if absf(dir.x) > 0.5:
		_shape.size = Vector2(_reach, THICK)
		_area.position = Vector2(dir.x * _reach * 0.5, 0.0)
	else:
		_shape.size = Vector2(THICK, _reach)
		_area.position = Vector2(0.0, dir.y * _reach * 0.5)


## The beam kills the instant it fires, including anyone already standing in
## it — body_entered alone only ever catches a crossing, and someone who was
## already there when the phase flipped never crosses anything.
func _check_overlap() -> void:
	await get_tree().physics_frame
	if not is_inside_tree() or _phase != 2:
		return
	for body in _area.get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).kill()


func _draw() -> void:
	if _phase == 0:
		return
	var thick := 1.0 if _phase == 1 else 4.0
	var fill := Palette.CYAN if _phase == 1 else Palette.WHITE
	var rect: Rect2
	if absf(dir.x) > 0.5:
		rect = Rect2(0.0 if dir.x > 0.0 else -_reach, -thick * 0.5, _reach, thick)
	else:
		rect = Rect2(-thick * 0.5, 0.0 if dir.y > 0.0 else -_reach, thick, _reach)
	draw_rect(rect, fill)
	if _phase == 2:
		Util.draw_panel(self, rect, Color(0, 0, 0, 0), Palette.CYAN)
