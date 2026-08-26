class_name GhostPlayer
extends Node2D

## Step 25 — the personal-best ghost. Visual only, on purpose: no collision,
## no sound, no particles. A ghost that competed for attention the way the
## real player does would be worse than no ghost — it has to be peripheral
## reading, a line the eye can check without it ever demanding a reaction.

const SAMPLE_HZ := 20      # matches GhostStore.SAMPLE_HZ; kept separate so
                           # this file has no load-time dependency on disk IO
const TILE := 8.0

var samples: PackedVector2Array = PackedVector2Array()
## Sample indices where the recorded run landed a ground pound — see
## GhostStore.save(). A Dictionary rather than the raw array so crossing one
## during playback is a lookup, not a scan.
var _pound_at: Dictionary = {}
## Read exactly like Player.gravity_zone_at: the room's own zone rects, not
## anything recorded, since the zone is a property of the room and the ghost
## walks the same room the real run did.
var gravity_zone_at: Callable
var _t := 0.0
var _last_i := -1
var _sprite: Sprite2D


func setup(recorded: PackedVector2Array, pounds: PackedInt32Array = PackedInt32Array()) -> void:
	samples = recorded
	_pound_at = {}
	for idx in pounds:
		_pound_at[idx] = true


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("player_idle")
	_sprite.modulate = Color(Palette.CYAN_DARK.r, Palette.CYAN_DARK.g, Palette.CYAN_DARK.b, 0.4)
	add_child(_sprite)
	restart()


func _process(delta: float) -> void:
	if samples.size() < 2 or not visible:
		return
	_t += delta * float(SAMPLE_HZ)
	var i := int(_t)
	if i >= samples.size() - 1:
		visible = false
		return
	var frac := _t - float(i)
	global_position = samples[i].lerp(samples[i + 1], frac)
	var dx := samples[i + 1].x - samples[i].x
	if dx < -0.1:
		_sprite.flip_h = true
	elif dx > 0.1:
		_sprite.flip_h = false

	if gravity_zone_at.is_valid():
		var tx := floori(global_position.x / TILE)
		var ty := floori(global_position.y / TILE)
		_sprite.flip_v = bool(gravity_zone_at.call(tx, ty))

	# Every index the trace crossed since last frame, not just `i` itself —
	# at low framerate more than one sample can pass in a single _process
	# call, and a pound sitting in that gap must not be skipped.
	for idx in range(_last_i + 1, i + 1):
		if _pound_at.has(idx):
			_squash()
	_last_i = i


## Same shape as Player._squash(): a landing pound flattens the sprite and
## the tween eases it back, so the ghost's landings read exactly like the
## real one it was recorded from.
func _squash() -> void:
	_sprite.scale = Vector2(1.5, 0.5)
	var t := create_tween()
	t.tween_property(_sprite, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Runs the trace from its own start, independent of whatever frame the room
## itself restarts on — a death restart calls this the same way _ready() does.
func restart() -> void:
	_t = 0.0
	_last_i = -1
	visible = samples.size() >= 2
	if _sprite != null:
		_sprite.scale = Vector2.ONE
		_sprite.flip_v = false
	if not samples.is_empty():
		global_position = samples[0]
