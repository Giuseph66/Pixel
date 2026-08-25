class_name RetractSpike
extends Node2D

## A spike on a clock: flat and harmless, then a blink of warning, then up and
## lethal. The beat is the one the timed blocks already taught, so a player who
## can read 't' can read this without being told.
##
## The warning is the whole mechanic. It never shortens, not even when endless
## winds the room up — a hazard you cannot see coming is not a harder hazard,
## it is a coin flip.

const PERIOD := 1.15            # same clock as TimedBlock, on purpose
const WARN := 0.3               # blinking, still safe
const UP := 0.45                # risen, lethal
const MAX_SCALE := 1.6          # past this the safe window stops being one
const BLINK := 0.08

var inverted := false           # 'Z' starts half a beat ahead of 'z'
var speed_scale := 1.0

var _time := 0.0
var _area: Area2D
var _sprite: Sprite2D
var _lethal := false


func setup(starts_inverted: bool) -> void:
	inverted = starts_inverted


func _ready() -> void:
	_time = PERIOD * 0.5 if inverted else 0.0

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("spike_low")
	add_child(_sprite)

	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	_area.monitoring = false
	# The player is a body, not an area. Watching for areas is why an earlier
	# version of this never killed anybody.
	_area.body_entered.connect(_on_body_entered)
	add_child(_area)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Same forgiving box as a fixed spike, and centred like one: this node sits
	# at the middle of its tile, so the shape needs no offset of its own.
	rect.size = Vector2(6, 4)
	shape.shape = rect
	shape.position.y = 2.0
	_area.add_child(shape)


func _physics_process(delta: float) -> void:
	_time = fmod(_time + delta * minf(speed_scale, MAX_SCALE), PERIOD)

	var up := _time >= PERIOD - UP
	var warning := not up and _time >= PERIOD - UP - WARN

	if up != _lethal:
		_lethal = up
		# Never touch monitoring inside the physics step directly.
		_area.set_deferred("monitoring", up)
		if up:
			_check_overlap()

	if up:
		_sprite.texture = PixelArt.tex("spike_up")
		_sprite.modulate = Color.WHITE
	elif warning:
		# Blink in place while still flat: the tell is the flashing, and the
		# player is safe to stand here for the whole of it.
		_sprite.texture = PixelArt.tex("spike_low")
		_sprite.modulate = Palette.WHITE if fmod(_time, BLINK * 2.0) < BLINK \
			else Color.WHITE
	else:
		_sprite.texture = PixelArt.tex("spike_low")
		_sprite.modulate = Color.WHITE


## Rising underneath somebody has to kill them. body_entered only fires on a
## crossing, and a player standing still is not crossing anything.
func _check_overlap() -> void:
	await get_tree().physics_frame
	if not is_inside_tree() or not _lethal:
		return
	for body in _area.get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).kill()
