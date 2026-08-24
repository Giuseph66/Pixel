class_name Player
extends CharacterBody2D

## Movement is the whole game, so it gets the whole toolbox: acceleration
## curves, a variable-height jump, coyote time, a jump buffer, wall slides and
## wall jumps. Every constant below is in pixels and seconds.

signal died
signal gem_grabbed(position: Vector2)
signal bounced(position: Vector2)
signal pounded(position: Vector2)

const WIDTH := 6
const HEIGHT := 10
const TILE := 8.0

const RUN_SPEED := 112.0
const ACCEL_GROUND := 1000.0
const ACCEL_AIR := 640.0
const FRICTION_GROUND := 1250.0
const FRICTION_AIR := 260.0
const FRICTION_ICE := 120.0       # ~1/10 of ground friction
const ACCEL_ICE := 420.0          # accelerates more slowly on ice too

const CONVEYOR_PUSH := 55.0       # px/s pushed by moving belts, ~half run speed

const GRAVITY_UP := 900.0
const GRAVITY_DOWN := 1180.0
const MAX_FALL := 330.0

const JUMP_VELOCITY := -262.0
const JUMP_CUT := 0.42          # velocity kept when the jump key is released early
const COYOTE_TIME := 0.09
const JUMP_BUFFER := 0.11

const WALL_SLIDE_SPEED := 58.0
const WALL_JUMP := Vector2(152.0, -252.0)
const WALL_LOCK := 0.13         # input is ignored briefly after a wall jump
const WALL_CLING := 24.0        # lean held into the wall so contact is not lost

const SPRING_VELOCITY := -450.0

# --- dash -------------------------------------------------------------------
# One charge, spent in the air and given back by the ground, a wall, a stomp or
# a crystal. It is the only move that ignores gravity, which is what makes it
# read as a different verb rather than a longer jump.
const DASH_SPEED := 232.0
const DASH_TIME := 0.14
const DASH_KEEP := 0.55         # share of dash speed kept when it ends
const DASH_COOLDOWN := 0.09

# --- ground pound -----------------------------------------------------------
# Down plus jump in mid-air. It commits: no steering on the way down and a beat
# of recovery on landing, paid for with the ability to break blocks, clear
# anything standing where you land, and get the dash back.
const POUND_SPEED := 430.0
const POUND_HANG := 0.08        # a held breath before the drop, so it reads
const POUND_RECOVER := 0.13
const POUND_REACH := 13.0       # pixels around the landing that get cleared

## Stomping enemies without touching the ground pays more each time.
const CHAIN_STEP := 0.09
const CHAIN_MAX := 1.45

var alive := true
var frozen := false             # set once the room is won; control is over
var has_dash := true
## Set by the level before the player enters the tree. The story hands these
## over as its rooms unlock; endless grants both from the first room.
var dash_unlocked := true
var pound_unlocked := true
var facing := 1
## Where the feet were at the start of this frame. Enemies decide a stomp from
## this rather than from velocity: Area2D overlaps arrive a frame late, and by
## then a fall has often already ended on the floor with velocity back to zero.
var previous_bottom := 0.0
var _coyote := 0.0
var _buffer := 0.0
var _lock := 0.0
var _anim := 0.0
var _was_on_floor := false
var _wall_dir := 0
var _dash := 0.0                # seconds of dash left
var _dash_dir := Vector2.ZERO
var _dash_cool := 0.0
var _pound := 0                 # 0 none, 1 hanging, 2 falling
var _pound_hang := 0.0
var _recover := 0.0
var _chain := 0

var sprite: Sprite2D
var fx: Fx


func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 4.0
	floor_max_angle = deg_to_rad(46.0)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH, HEIGHT)
	shape.shape = rect
	add_child(shape)

	sprite = Sprite2D.new()
	sprite.texture = PixelArt.tex("player_idle")
	add_child(sprite)

	previous_bottom = position.y + HEIGHT * 0.5
	# The two moves you have before the game teaches you anything.
	Save.discover("run")
	Save.discover("jump")


func _physics_process(delta: float) -> void:
	if not alive or frozen:
		return

	previous_bottom = global_position.y + HEIGHT * 0.5
	_anim += delta
	_coyote = maxf(_coyote - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)
	_lock = maxf(_lock - delta, 0.0)
	_dash_cool = maxf(_dash_cool - delta, 0.0)
	_recover = maxf(_recover - delta, 0.0)

	var input := 0.0
	if _lock <= 0.0:
		input = Input.get_axis("p_left", "p_right")

	if Input.is_action_just_pressed("p_jump"):
		_buffer = JUMP_BUFFER

	if _recover > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION_GROUND * delta)
		velocity.y += GRAVITY_DOWN * gravity_scale * delta
	elif _pound > 0:
		_tick_pound(delta)
	elif _dash > 0.0:
		_tick_dash(delta)
	else:
		_try_pound()
		_try_dash(input)
		_apply_horizontal(input, delta)
		_apply_gravity(input, delta)
		_handle_jump()

	velocity += external_force * delta
	external_force = Vector2.ZERO
	move_and_slide()

	if is_on_floor():
		_coyote = COYOTE_TIME
		_chain = 0
		refill_dash()
		if not _was_on_floor:
			_on_land()
	elif _wall_dir != 0:
		refill_dash()
	_was_on_floor = is_on_floor()

	_update_sprite(input)


# ----------------------------------------------------------------- pound ---

func _try_pound() -> void:
	if not pound_unlocked:
		return
	if is_on_floor() or _wall_dir != 0:
		return
	if not (Input.is_action_pressed("p_down") and Input.is_action_just_pressed("p_jump")):
		return

	_found("pound")
	_pound = 1
	_pound_hang = POUND_HANG
	_buffer = 0.0
	velocity = Vector2.ZERO
	_squash(Vector2(0.6, 1.4))
	Audio.play_varied("pound")


func _tick_pound(delta: float) -> void:
	if _pound == 1:
		_pound_hang -= delta
		velocity = Vector2.ZERO
		if _pound_hang <= 0.0:
			_pound = 2
		return

	velocity = Vector2(0.0, POUND_SPEED)
	if fx != null and randf() < 0.6:
		fx.emit(_fx_at(Vector2(0, -4)), 1, Palette.CYAN_MID, 26.0,
			Vector2.UP, 0.7, 0.2, 40.0)

	if is_on_floor():
		_land_pound()


func _land_pound() -> void:
	_pound = 0
	_recover = POUND_RECOVER
	_chain = 0
	refill_dash()
	velocity = Vector2.ZERO
	_squash(Vector2(1.5, 0.5))
	Audio.play("stomp")
	if fx != null:
		fx.dust(_fx_at(Vector2(0, HEIGHT * 0.5)), Palette.CYAN, 14)
	# The level owns what a landing hits — blocks, slimes, bats. It knows where
	# they all are; the player only knows it hit the ground hard.
	pounded.emit(global_position + Vector2(0, HEIGHT * 0.5))


func is_pounding() -> bool:
	return _pound == 2


## Note a first-time move and say so on screen. The callout is the only place
## the codex ever interrupts play, and only ever once per entry.
func _found(entry: String) -> void:
	if not Save.discover(entry):
		return
	if fx != null:
		fx.popup(_fx_at(Vector2(0, -6)), Lang.t("codex.new"), Palette.CYAN, 0.9)


# ------------------------------------------------------------------ dash ---

func _try_dash(input: float) -> void:
	# Holding dash chains automatically whenever a new charge is available.
	if not dash_unlocked or not has_dash or _dash_cool > 0.0 \
			or not Input.is_action_pressed("p_dash"):
		return

	# Eight-way, taken from whatever is held. Nothing held dashes the way you
	# are already facing, so it never fires into a wall you were backing away
	# from.
	var vertical := Input.get_axis("p_up", "p_down")
	var dir := Vector2(input, vertical)
	if dir.length_squared() < 0.04:
		dir = Vector2(facing, 0.0)
	_dash_dir = dir.normalized()

	_found("dash")
	has_dash = false
	_dash = DASH_TIME
	_lock = DASH_TIME
	velocity = _dash_dir * DASH_SPEED
	facing = -1 if _dash_dir.x < -0.1 else (1 if _dash_dir.x > 0.1 else facing)
	Audio.play_varied("dash")
	_squash(Vector2(1.35, 0.65))
	if fx != null:
		fx.emit(_fx_at(), 8, Palette.CYAN, 90.0, -_dash_dir, 0.9, 0.3, 240.0)


func _tick_dash(delta: float) -> void:
	_dash -= delta
	velocity = _dash_dir * DASH_SPEED
	if fx != null and randf() < 0.7:
		fx.emit(_fx_at(), 1, Palette.CYAN_MID, 18.0, -_dash_dir, 0.6, 0.22, 70.0)
	if _dash <= 0.0:
		# Keep some of it: a dash that dumps you to a standstill kills every
		# chain the move exists to enable.
		velocity = _dash_dir * DASH_SPEED * DASH_KEEP
		if _dash_dir.y < 0.0:
			velocity.y = maxf(velocity.y, JUMP_VELOCITY * 0.5)
		_dash_cool = DASH_COOLDOWN


## Give the charge back. Ground, walls, stomps, springs and crystals all do.
func refill_dash() -> void:
	has_dash = true


func _apply_horizontal(input: float, delta: float) -> void:
	var target := input * RUN_SPEED * speed_scale
	var rate := 0.0
	if absf(input) > 0.01:
		# Acceleration depends on surface
		if is_on_floor():
			var tile := ground_tile()
			rate = ACCEL_ICE if tile == "~" else ACCEL_GROUND
		else:
			rate = ACCEL_AIR
	else:
		# Friction depends on surface
		if is_on_floor():
			var tile := ground_tile()
			rate = FRICTION_ICE if tile == "~" else FRICTION_GROUND
		else:
			rate = FRICTION_AIR
	velocity.x = move_toward(velocity.x, target, rate * delta)
	if absf(input) > 0.01:
		facing = -1 if input < 0.0 else 1


## Once you touch a wall you stay on it. Letting go of the stick does not drop
## you — only steering away from the wall, jumping, or running out of wall
## does. Holding a direction to avoid falling is busywork, not difficulty.
func _apply_gravity(input: float, delta: float) -> void:
	_wall_dir = 0
	if not is_on_floor() and is_on_wall_only():
		var normal := get_wall_normal()
		if absf(normal.x) > 0.7:
			var dir := int(-signf(normal.x))        # 1 = wall is on the right
			var steering_away := absf(input) > 0.01 and signf(input) != float(dir)
			if not steering_away:
				_wall_dir = dir
				_found("wall")

	var g := GRAVITY_UP if velocity.y < 0.0 else GRAVITY_DOWN
	velocity.y += g * gravity_scale * delta

	if _wall_dir != 0 and velocity.y > 0.0:
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
		# Air friction would otherwise peel you off the wall within a few
		# frames, which is what made the slide feel like it kept dropping you.
		velocity.x = _wall_dir * WALL_CLING
		if fx != null and randf() < 0.25:
			fx.emit(_fx_at(Vector2(_wall_dir * 4.0, 2.0)), 1,
				Palette.CYAN_DARK, 22.0, Vector2(-_wall_dir, -0.4), 0.9, 0.28, 90.0)
	else:
		velocity.y = minf(velocity.y, MAX_FALL * gravity_scale)


func _handle_jump() -> void:
	if _buffer > 0.0:
		if _coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			_buffer = 0.0
			_coyote = 0.0
			Audio.play_varied("jump")
			if fx != null:
				fx.dust(_fx_at(Vector2(0, HEIGHT * 0.5)), Palette.CYAN_DARK, 6)
		elif _wall_dir != 0:
			velocity.y = WALL_JUMP.y
			velocity.x = -_wall_dir * WALL_JUMP.x
			facing = -_wall_dir
			_lock = WALL_LOCK
			_buffer = 0.0
			Audio.play_varied("wall_jump")
			if fx != null:
				fx.emit(_fx_at(Vector2(_wall_dir * 4.0, 0.0)), 6,
					Palette.CYAN, 70.0, Vector2(-_wall_dir, -0.5), 1.2, 0.3, 200.0)

	# Releasing the button early cuts the rise short.
	if Input.is_action_just_released("p_jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT


func _on_land() -> void:
	Audio.play_varied("land", 0.1)
	if fx != null:
		fx.dust(_fx_at(Vector2(0, HEIGHT * 0.5)), Palette.CYAN_DARK, 7)
	_squash(Vector2(1.25, 0.75))


## Particles live in the level's coordinate space, not the player's.
func _fx_at(offset: Vector2 = Vector2.ZERO) -> Vector2:
	return fx.to_local(global_position + offset)


func _squash(to: Vector2) -> void:
	sprite.scale = to
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_sprite(input: float) -> void:
	var key := "player_idle"
	if not is_on_floor():
		if _wall_dir != 0:
			key = "player_wall"
		elif velocity.y < -20.0:
			key = "player_jump"
		elif velocity.y > 40.0:
			key = "player_fall"
	elif absf(velocity.x) > 12.0:
		key = "player_run_a" if fmod(_anim * 9.0, 2.0) < 1.0 else "player_run_b"

	if _dash > 0.0:
		key = "player_jump"
	if _pound > 0:
		key = "player_fall"

	sprite.texture = PixelArt.tex(key)
	# Spent dash reads as a dimmer sprite — the charge has to be visible
	# without a meter stealing screen from a 480x270 room.
	sprite.modulate = Color(1, 1, 1) if (has_dash or not dash_unlocked) \
		else Color(0.62, 0.68, 0.9)
	if _wall_dir != 0:
		sprite.flip_h = _wall_dir > 0
	else:
		sprite.flip_h = facing < 0


# ------------------------------------------------------------- reactions ---

func spring_bounce() -> void:
	if frozen or not alive:
		return
	refill_dash()
	_dash = 0.0
	velocity.y = SPRING_VELOCITY
	_buffer = 0.0
	_squash(Vector2(0.7, 1.35))
	Audio.play("spring")
	bounced.emit(global_position)


## Bouncing off an enemy. Each one taken without touching the ground in
## between throws you higher, so a row of them is a route rather than a queue.
func stomp() -> void:
	if frozen or not alive:
		return
	_found("stomp")
	refill_dash()
	_dash = 0.0
	_pound = 0
	_chain += 1
	var boost := minf(1.0 + float(_chain - 1) * CHAIN_STEP, CHAIN_MAX)
	velocity.y = JUMP_VELOCITY * 0.78 * boost
	_squash(Vector2(1.3, 0.7))
	Audio.play_varied("stomp")


## Surface consultado a cada frame: injetado por Level antes de entrar na árvore.
var surface_at: Callable
var external_force := Vector2.ZERO
var speed_scale := 1.0
var gravity_scale := 1.0

## Caractere sob os pés, ou "." quando não há chão.
func ground_tile() -> String:
	if not surface_at.is_valid() or not is_on_floor():
		return "."
	var tx := floori(global_position.x / TILE)
	var ty := floori((global_position.y + HEIGHT * 0.5 + 2.0) / TILE)
	return surface_at.call(tx, ty)


func push(force: Vector2) -> void:
	external_force += force


## Walk into the exit: hand control over and get pulled into the frame.
func enter_door(at: Vector2) -> void:
	if frozen:
		return
	frozen = true
	velocity = Vector2.ZERO
	sprite.texture = PixelArt.tex("player_idle")

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", at, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.15, 0.15), 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func kill() -> void:
	if not alive or frozen:
		return
	alive = false
	velocity = Vector2.ZERO
	sprite.visible = false
	Audio.play("death")
	if fx != null:
		fx.emit(_fx_at(), 26, Palette.CYAN, 130.0, Vector2.ZERO, TAU, 0.6, 300.0)
		fx.emit(_fx_at(), 10, Palette.WHITE, 90.0, Vector2.ZERO, TAU, 0.4, 260.0)
	died.emit()


func grab_gem(at: Vector2) -> void:
	gem_grabbed.emit(at)
