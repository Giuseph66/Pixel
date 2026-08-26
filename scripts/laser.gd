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
## A beam only ever has one portal pair to bounce off in a room, so two hops
## already covers every real layout — this is a loop guard, not a design
## target, for the degenerate case of an exit that stares straight back into
## an entrance.
const MAX_BOUNCES := 4

var speed_scale := 1.0
var dir := Vector2.RIGHT
var is_solid_at: Callable
## Optional. Given the tile just ahead of the beam, returns the Portal to
## re-emerge from if that tile is a portal, or null. Beam bends there instead
## of stopping — same substitution a body gets from stepping into one.
var portal_at: Callable

var _time := 0.0
var _phase := 0          # 0 sleep, 1 warn, 2 fire
var _frozen := 0.0       # step 12/16 — a switch can buy a safe window
## One entry per straight stretch of beam: {pos: Vector2 (local, the start —
## the emitter for the first, a portal's centre for every bounce after),
## dir: Vector2, reach: float}. A beam with no portal in its path is always
## exactly one segment, so every caller that only ever knew one straight
## beam keeps working unchanged.
var _segments: Array = []
var _reach := 8.0        # last segment's reach — kept for network sync
var _sprite: Sprite2D
var _area: Area2D


func setup(direction: Vector2, solid_check: Callable, portal_check: Callable = Callable()) -> void:
	dir = direction
	is_solid_at = solid_check
	portal_at = portal_check


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("laser_idle")
	add_child(_sprite)

	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	_area.monitoring = false
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
	_segments.clear()
	if not is_solid_at.is_valid():
		_reach = 8.0
		return
	# position is always a tile CENTER (tile_center() = tx*8+4), so
	# position/8.0 lands exactly on tx+0.5. roundi() rounds .5 up, silently
	# measuring from tx+1 instead of tx — off by one tile in the firing
	# direction, which either cut the beam a tile short or drove it a tile
	# into the wall depending on which way it fired. floori() lands on tx.
	var seg_pos := position
	var seg_dir := dir
	var budget := MAX_REACH_TILES
	var bounces := 0
	while true:
		var tx := floori(seg_pos.x / 8.0)
		var ty := floori(seg_pos.y / 8.0)
		var steps := 0
		var exit_portal: Portal = null
		while steps < budget:
			var nx := tx + int(seg_dir.x) * (steps + 1)
			var ny := ty + int(seg_dir.y) * (steps + 1)
			if is_solid_at.call(nx, ny):
				break
			if portal_at.is_valid():
				var found: Portal = portal_at.call(nx, ny)
				if found != null:
					exit_portal = found
					steps += 1
					break
			steps += 1
		_reach = float(steps) * 8.0 + 4.0
		_segments.append({"pos": seg_pos, "dir": seg_dir, "reach": _reach})
		budget -= steps
		bounces += 1
		if exit_portal == null or budget <= 0 or bounces >= MAX_BOUNCES:
			break
		seg_pos = exit_portal.position
		seg_dir = exit_portal.facing


func _update_shape() -> void:
	const THICK := 4.0
	for child in _area.get_children():
		child.queue_free()
	for seg: Dictionary in _segments:
		var d: Vector2 = seg["dir"]
		var reach: float = seg["reach"]
		var shape := RectangleShape2D.new()
		var cs := CollisionShape2D.new()
		if absf(d.x) > 0.5:
			shape.size = Vector2(reach, THICK)
			cs.position = (seg["pos"] as Vector2) - position + Vector2(d.x * reach * 0.5, 0.0)
		else:
			shape.size = Vector2(THICK, reach)
			cs.position = (seg["pos"] as Vector2) - position + Vector2(0.0, d.y * reach * 0.5)
		cs.shape = shape
		_area.add_child(cs)


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


func network_state() -> Dictionary:
	return {"time": _time, "phase": _phase, "frozen": _frozen, "reach": _reach}


func apply_network_state(state: Dictionary) -> void:
	_time = float(state.get("time", _time))
	_frozen = float(state.get("frozen", _frozen))
	_reach = float(state.get("reach", _reach))
	var phase := int(state.get("phase", _phase))
	if phase == _phase:
		return
	_phase = phase
	_area.set_deferred("monitoring", _phase == 2)
	_sprite.texture = PixelArt.tex(["laser_idle", "laser_warn", "laser_fire"][_phase])
	if _phase == 2:
		_update_shape()
	queue_redraw()


func _draw() -> void:
	if _phase == 0:
		return
	var thick := 1.0 if _phase == 1 else 4.0
	var fill := Palette.CYAN if _phase == 1 else Palette.WHITE
	for seg: Dictionary in _segments:
		var d: Vector2 = seg["dir"]
		var reach: float = seg["reach"]
		var origin: Vector2 = (seg["pos"] as Vector2) - position
		var rect: Rect2
		if absf(d.x) > 0.5:
			rect = Rect2(origin.x + (0.0 if d.x > 0.0 else -reach), origin.y - thick * 0.5,
				reach, thick)
		else:
			rect = Rect2(origin.x - thick * 0.5, origin.y + (0.0 if d.y > 0.0 else -reach),
				thick, reach)
		draw_rect(rect, fill)
		if _phase == 2:
			Util.draw_panel(self, rect, Color(0, 0, 0, 0), Palette.CYAN)
