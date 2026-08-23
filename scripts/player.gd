class_name Player
extends CharacterBody2D

## Movement is the whole game, so it gets the whole toolbox: acceleration
## curves, a variable-height jump, coyote time, a jump buffer, wall slides and
## wall jumps. Every constant below is in pixels and seconds.

signal died
signal gem_grabbed(position: Vector2)
signal bounced(position: Vector2)

const WIDTH := 6
const HEIGHT := 10

const RUN_SPEED := 112.0
const ACCEL_GROUND := 1000.0
const ACCEL_AIR := 640.0
const FRICTION_GROUND := 1250.0
const FRICTION_AIR := 260.0

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

var alive := true
var frozen := false             # set once the room is won; control is over
var facing := 1
var _coyote := 0.0
var _buffer := 0.0
var _lock := 0.0
var _anim := 0.0
var _was_on_floor := false
var _wall_dir := 0

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


func _physics_process(delta: float) -> void:
	if not alive or frozen:
		return

	_anim += delta
	_coyote = maxf(_coyote - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)
	_lock = maxf(_lock - delta, 0.0)

	var input := 0.0
	if _lock <= 0.0:
		input = Input.get_axis("p_left", "p_right")

	if Input.is_action_just_pressed("p_jump"):
		_buffer = JUMP_BUFFER

	_apply_horizontal(input, delta)
	_apply_gravity(input, delta)
	_handle_jump()

	move_and_slide()

	if is_on_floor():
		_coyote = COYOTE_TIME
		if not _was_on_floor:
			_on_land()
	_was_on_floor = is_on_floor()

	_update_sprite(input)


func _apply_horizontal(input: float, delta: float) -> void:
	var target := input * RUN_SPEED
	var rate := 0.0
	if absf(input) > 0.01:
		rate = ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	else:
		rate = FRICTION_GROUND if is_on_floor() else FRICTION_AIR
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

	var g := GRAVITY_UP if velocity.y < 0.0 else GRAVITY_DOWN
	velocity.y += g * delta

	if _wall_dir != 0 and velocity.y > 0.0:
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
		# Air friction would otherwise peel you off the wall within a few
		# frames, which is what made the slide feel like it kept dropping you.
		velocity.x = _wall_dir * WALL_CLING
		if fx != null and randf() < 0.25:
			fx.emit(_fx_at(Vector2(_wall_dir * 4.0, 2.0)), 1,
				Palette.CYAN_DARK, 22.0, Vector2(-_wall_dir, -0.4), 0.9, 0.28, 90.0)
	else:
		velocity.y = minf(velocity.y, MAX_FALL)


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

	sprite.texture = PixelArt.tex(key)
	if _wall_dir != 0:
		sprite.flip_h = _wall_dir > 0
	else:
		sprite.flip_h = facing < 0


# ------------------------------------------------------------- reactions ---

func spring_bounce() -> void:
	if frozen or not alive:
		return
	velocity.y = SPRING_VELOCITY
	_buffer = 0.0
	_squash(Vector2(0.7, 1.35))
	Audio.play("spring")
	bounced.emit(global_position)


func stomp() -> void:
	if frozen or not alive:
		return
	velocity.y = JUMP_VELOCITY * 0.78
	_squash(Vector2(1.3, 0.7))
	Audio.play_varied("stomp")


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
