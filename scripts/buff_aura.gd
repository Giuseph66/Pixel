class_name BuffAura
extends Node2D

## Bombado (doc/bombadao) — the room reacting to his weight.
##
## The project has no shader anywhere; darkness.gd says so outright and solves
## the 'dark' modifier with four draw_rect() calls. This does the same, with a
## few more rectangles: everything below is a 1px axis-aligned rect, which is
## the only drawing primitive the art style allows.
##
## Added as a child of Level after terrain and entities, so it covers both.
## Level is added to Main before Hud, which keeps the clock and the gem count
## readable no matter how heavy the weather gets.

const SCREEN := Vector2(480.0, 270.0)

## The room is already nearly black (Palette.BG is 0f0f1b), so darkening it
## further does almost nothing — the first version of this drew a 30% black
## veil over the whole screen and was invisible in play. What reads instead is
## a colour shift: a warm veil pushes the whole room off its blue and makes it
## look pressurised, and it costs no legibility because it lifts the darks
## rather than crushing them.
const HEAT := 0.13
const DIM := 0.20
## Four steps of vignette, hard-edged on purpose. This is where most of the
## weight comes from — the corners going properly black.
const VIGNETTE_BAND := 18.0
const VIGNETTE_STEP := 0.13
const VIGNETTE_STEPS := 4

const EMBERS := 70
const EMBER_RISE := Vector2(14.0, 38.0)   # px/s, min and max
const EMBER_SWAY := 5.0

## One shockwave every WAVE_EVERY seconds, running out along the floor from
## his feet. A hollow square read as a UI box at this resolution; two segments
## travelling outward along the ground read as the ground taking it.
const WAVE_EVERY := 1.5
const WAVE_MAX := 96.0
const WAVE_SPEED := 150.0
const WAVE_ARM := 9.0

const FADE_IN := 0.5
const FADE_OUT := 0.4

var player: Player

var _intensity := 0.0
var _target := 0.0
var _time := 0.0
var _ring_t := 0.0
## Live shockwaves, each just an age in seconds and where it was born.
var _waves: Array[Dictionary] = []
## Embers are three parallel arrays rather than objects: they never die, they
## only wrap, so there is nothing to allocate per frame.
var _ember_x := PackedFloat32Array()
var _ember_y := PackedFloat32Array()
var _ember_speed := PackedFloat32Array()
var _ember_phase := PackedFloat32Array()
var _ember_color: Array[Color] = []


func _ready() -> void:
	# Deliberately left at 0: Level places this node between the terrain and
	# the entities by tree order alone, and any z_index at all would hoist it
	# back over the players and grey them out.
	z_index = 0
	_ember_x.resize(EMBERS)
	_ember_y.resize(EMBERS)
	_ember_speed.resize(EMBERS)
	_ember_phase.resize(EMBERS)
	_ember_color.resize(EMBERS)
	var palette := [Palette.CYAN, Palette.CYAN_MID, Palette.GOLD]
	for i in EMBERS:
		_ember_x[i] = randf() * SCREEN.x
		_ember_y[i] = randf() * SCREEN.y
		_ember_speed[i] = randf_range(EMBER_RISE.x, EMBER_RISE.y)
		_ember_phase[i] = randf() * TAU
		_ember_color[i] = palette[randi() % palette.size()]


## True on the way in. False starts the fade out and frees the node once it is
## done — the caller drops its reference immediately, so nothing else has to
## remember this node exists.
func set_active(on: bool) -> void:
	_target = 1.0 if on else 0.0


func _process(delta: float) -> void:
	_time += delta

	var rate := 1.0 / (FADE_IN if _target > _intensity else FADE_OUT)
	_intensity = move_toward(_intensity, _target, rate * delta)
	if _intensity <= 0.0 and _target <= 0.0:
		queue_free()
		return

	for i in EMBERS:
		_ember_y[i] -= _ember_speed[i] * delta * (0.4 + 0.6 * _intensity)
		if _ember_y[i] < -2.0:
			_ember_y[i] = SCREEN.y + 2.0
			_ember_x[i] = randf() * SCREEN.x

	_ring_t -= delta
	if _ring_t <= 0.0 and _target > 0.0 and player != null and is_instance_valid(player):
		_ring_t = WAVE_EVERY
		_waves.append({
			# Born at the feet, not at the centre: the ground is what is being
			# pushed on.
			"pos": player.global_position - global_position
				+ Vector2(0.0, player.body_height() * 0.5),
			"age": 0.0,
		})
	var live: Array[Dictionary] = []
	for wave: Dictionary in _waves:
		wave["age"] = float(wave["age"]) + delta
		if float(wave["age"]) * WAVE_SPEED < WAVE_MAX:
			live.append(wave)
	_waves = live

	queue_redraw()


func _draw() -> void:
	if _intensity <= 0.001:
		return
	var strength := _intensity

	# 1. The veil: a little black to flatten the mid-tones, and a warm pass over
	# the top that takes the whole room off its usual blue.
	_veil(Rect2(Vector2.ZERO, SCREEN), Palette.OUTLINE, DIM * strength)
	_veil(Rect2(Vector2.ZERO, SCREEN), Palette.MAGENTA_DARK, HEAT * strength)

	# 2. Vignette, hard steps in from each edge.
	for step in VIGNETTE_STEPS:
		var inset := VIGNETTE_BAND * float(step)
		var band := VIGNETTE_BAND
		var alpha := VIGNETTE_STEP * strength
		_veil(Rect2(0.0, inset, SCREEN.x, band), Palette.OUTLINE, alpha)
		_veil(Rect2(0.0, SCREEN.y - inset - band, SCREEN.x, band), Palette.OUTLINE, alpha)
		_veil(Rect2(inset, 0.0, band, SCREEN.y), Palette.OUTLINE, alpha)
		_veil(Rect2(SCREEN.x - inset - band, 0.0, band, SCREEN.y), Palette.OUTLINE, alpha)

	# 3. Embers drifting up. The sway is a sine of position, not of time, so a
	# pause never freezes them into a straight column.
	for i in EMBERS:
		var sway := sin(_ember_y[i] * 0.06 + _ember_phase[i]) * EMBER_SWAY
		var c := _ember_color[i]
		c.a = 0.85 * strength
		# Every third ember is a two-pixel cinder, so the field has some weight
		# to it instead of reading as uniform dust.
		var size := 2.0 if i % 3 == 0 else 1.0
		draw_rect(Rect2(roundf(_ember_x[i] + sway), roundf(_ember_y[i]), size, size), c)

	# 4. Shockwaves running out along the floor line, both ways.
	for wave: Dictionary in _waves:
		var r: float = float(wave["age"]) * WAVE_SPEED
		var fade := 1.0 - r / WAVE_MAX
		var c := Palette.CYAN
		c.a = 0.7 * fade * strength
		var origin: Vector2 = wave["pos"]
		var y := roundf(origin.y - 1.0)
		var thickness := maxf(1.0, roundf(2.0 * fade))
		draw_rect(Rect2(roundf(origin.x + r), y, WAVE_ARM, thickness), c)
		draw_rect(Rect2(roundf(origin.x - r - WAVE_ARM), y, WAVE_ARM, thickness), c)

	# 5. Two pressure bars, top and bottom, jittering a pixel. Cheap, and they
	# read as the frame itself straining.
	var jitter := roundf(sin(_time * 31.0))
	var bar := Palette.CYAN_MID
	bar.a = 0.35 * strength
	draw_rect(Rect2(0.0, 3.0 + jitter, SCREEN.x, 1.0), bar)
	draw_rect(Rect2(0.0, SCREEN.y - 4.0 - jitter, SCREEN.x, 1.0), bar)


func _veil(rect: Rect2, color: Color, alpha: float) -> void:
	var c := color
	c.a = alpha
	draw_rect(rect, c)

