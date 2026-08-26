class_name Player
extends CharacterBody2D

## Movement is the whole game, so it gets the whole toolbox: acceleration
## curves, a variable-height jump, coyote time, a jump buffer, wall slides and
## wall jumps. Every constant below is in pixels and seconds.

signal died
signal gem_grabbed(position: Vector2)
signal bounced(position: Vector2)
signal pounded(position: Vector2)
## Step 10 — combo. Each is a distinct aerial verb; repeating one is not a new
## count (the dash already needs a refill in between, which forces variety).
signal combo_changed(count: int, verb: int)
## Fired once, on landing, with whatever the combo was before it reset. Level
## reads this to cash in the score — combo_changed alone cannot tell "grew"
## from "about to end" apart.
signal combo_ended(final_count: int)
## Step 14 — phase blocks. Emitted the instant a dash starts and the instant
## it ends, so Level never has to poll is_dashing() to know when to react.
signal dash_changed(active: bool)
## A compact event lets the network reproduce a burst on the other screens.
## The particles themselves remain local, so their random motion stays cheap.
signal visual_event(kind: String, fx_position: Vector2, direction: Vector2)

## POUND is listed because the design does — a pound always resolves by
## touching the ground, which is the same instant the combo resets, so it is
## never actually seen as a distinct member. No call site sets that bit.
enum Verb { DASH, WALL, STOMP, SPRING, POUND }

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

## Step 19 — wall boost. A wall jump thrown within the window of first contact
## leaves faster. Vertical reach never changes — only how far it carries —
## because a taller wall jump would quietly change what every existing room's
## alcançability was built against.
const WALL_WINDOW := 0.09       # ~5 frames at 60fps, same order as COYOTE_TIME
const WALL_BOOST := 1.25        # 152 -> 190 px/s horizontal, on a perfect jump

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
# Down in mid-air, on its own. It commits: no steering on the way down and a
# beat of recovery on landing, paid for with the ability to break blocks, clear
# anything standing where you land, and get the dash back.
const POUND_SPEED := 430.0
const POUND_HANG := 0.08        # a held breath before the drop, so it reads
const POUND_RECOVER := 0.13
const POUND_REACH := 13.0       # pixels around the landing that get cleared

# --- footless ---------------------------------------------------------------
# What the landing costs. For two seconds the legs are gone: no walking, no
# jumping, and the body is short enough to fit through a one-tile gap. The dash
# still works, which is what keeps the state a move rather than a punishment —
# it is the only way to travel while it lasts.
#
# The collision box shrinks from the top down. Its bottom edge stays exactly
# where a standing player's is, so "feet" everywhere else in the game — lava's
# waterline, a slime reading whether it was stomped — keeps meaning the same
# thing and needs no idea that this state exists.
const FOOTLESS_TIME := 2.0
const FOOTLESS_HEIGHT := 6.0

## Stomping enemies without touching the ground pays more each time.
const CHAIN_STEP := 0.09
const CHAIN_MAX := 1.45

## Step 18 — standing still charges the next jump. JUMP_CUT still applies on
## top of the boosted velocity, same as any other jump — the charge changes
## how high, never whether letting go early still cuts it short.
const CHARGE_TIME := 0.35
const CHARGE_BOOST := 1.3

## Step 22 — gravity zones, hysteresis. A zone's own edge is a stable
## equilibrium: inside, gravity pushes you toward the edge and out; outside,
## it pushes you straight back in. Anything that drifts to that seam parks on
## it, and a per-frame reading then alternates forever. See
## _update_gravity_zone() for what that costs the player.
##
## Entering is the exact tile read it always was, so a zone one tile tall
## still has an inside; leaving needs the zone a clear GRAV_EXIT_MARGIN away.
## That margin has to beat the distance gravity carries the player during
## GRAV_DWELL (~8px at these constants), or the dwell alone throws them clear
## of a narrower band and re-arms the very transition the band exists to
## suppress.
const GRAV_EXIT_MARGIN := 12.0
const GRAV_DWELL := 0.12

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
## Step 22 — gravity zones. 1.0 normal, -1.0 inside a 'V' zone. Every place
## that sets or compares velocity.y multiplies by this first — see
## _update_gravity_zone() for the only place it changes, and up_direction for
## the one thing that keeps is_on_floor() and friends honest about it.
var gravity_dir := 1.0
## Seconds left before gravity_dir may change again — see GRAV_DWELL.
var _grav_dwell := 0.0
var _wall_dir := 0
## How long the current wall contact has held, measured as of the start of
## this frame — so a wall jump thrown on the very frame contact begins reads
## exactly 0.0, not one frame late.
var _wall_time := 0.0
var _dash := 0.0                # seconds of dash left
var _dash_dir := Vector2.ZERO
var _dash_cool := 0.0
var _pound := 0                 # 0 none, 1 hanging, 2 falling
var _pound_hang := 0.0
## gravity_dir at the moment the pound committed. _tick_pound() plunges
## toward this, not the live gravity_dir — see its own comment.
var _pound_dir := 1.0
## Legs gone since the last pound landed. The timer running out is necessary
## but not sufficient: standing back up inside a one-tile gap would leave the
## body embedded in terrain, so the state also waits for headroom.
var _footless := false
var _footless_left := 0.0
var _shape: CollisionShape2D
var _recover := 0.0
var _chain := 0
var combo := 0
var _combo_verbs := 0
var _charge := 0.0
var _charge_particle_t := 0.0

var sprite: Sprite2D
var fx: Fx

# --- echo --------------------------------------------------------------------
# Step 23. Off everywhere by default — echo_max is set by Level from the
# room's own data, and stays 0 outside the four rooms built for it. The world
# does not rewind with the player: a gem stays taken, a block stays broken. A
# ring buffer of one second of physics is cheap enough to keep running
# whether or not the room ever uses it.
const ECHO_FRAMES := 60         # 1s at 60Hz of physics
var echo_max := 0
var echo_left := 0
var _echo_pos: PackedVector2Array = PackedVector2Array()
var _echo_vel: PackedVector2Array = PackedVector2Array()
var _echo_head := 0
var _echo_ghost: Sprite2D

## Multiplayer keeps the movement code shared with offline. A client runs its
## own player immediately; the host trusts that snapshot and relays it to the
## other peers, which interpolate remote players.
var peer_id := 1
var networked := false
var locally_controlled := true
var client_authority := false
var color_index := 0
var input_provider: Callable
var _network_target := Vector2.ZERO
var _network_age := 0.0
var _network_anim := "player_idle"
var _network_charge := 0.0
var _network_wall_dir := 0
var _sprite_key := "player_idle"
## Step 21 — ghost blocks. Whether any movement-relevant key is currently
## held, refreshed every physics frame regardless of what it actually did to
## velocity. GhostBlock reads this instead of speed: falling or getting
## knocked around by a spring is not a choice to move, and should not read as
## one just because it happens to have velocity.
var moving_input := false
var _door_entering := false

const PLAYER_COLORS := [
	Palette.CYAN,
	Palette.MAGENTA,
	Palette.GREEN,
	Palette.GOLD,
	Palette.PURPLE,
	Color("ff8957"),
	Color("85eaff"),
	Palette.GREY,
]
const PLAYER_COLOR_NAMES := ["AZUL", "ROSA", "VERDE", "OURO", "ROXO", "LARANJA", "CEU", "PRATA"]
static var _player_texture_cache: Dictionary = {}


func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 4.0
	floor_max_angle = deg_to_rad(46.0)

	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH, HEIGHT)
	_shape.shape = rect
	add_child(_shape)

	sprite = Sprite2D.new()
	sprite.texture = _player_texture("player_idle", color_index)
	add_child(sprite)

	previous_bottom = position.y + HEIGHT * 0.5 * gravity_dir
	# The two moves you have before the game teaches you anything.
	Save.discover("run")
	Save.discover("jump")

	_echo_pos.resize(ECHO_FRAMES)
	_echo_vel.resize(ECHO_FRAMES)
	_echo_pos.fill(global_position)
	_echo_vel.fill(Vector2.ZERO)
	echo_left = echo_max
	if echo_max > 0:
		_echo_ghost = Sprite2D.new()
		_echo_ghost.modulate = Color(Palette.PURPLE.r, Palette.PURPLE.g, Palette.PURPLE.b, 0.25)
		_echo_ghost.visible = false
		_echo_ghost.z_index = -1
		add_child(_echo_ghost)


func _physics_process(delta: float) -> void:
	if networked and Session.is_client() and not locally_controlled:
		_tick_remote(delta)
		return
	if networked and Session.is_host() and client_authority:
		_tick_remote(delta)
		return
	if not alive or frozen:
		return

	_update_gravity_zone(delta)
	previous_bottom = global_position.y + HEIGHT * 0.5 * gravity_dir
	_anim += delta
	_coyote = maxf(_coyote - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)
	_lock = maxf(_lock - delta, 0.0)
	_dash_cool = maxf(_dash_cool - delta, 0.0)
	_recover = maxf(_recover - delta, 0.0)
	_tick_footless(delta)
	_record_echo()

	var controls := _read_controls()
	moving_input = _held(controls, "left") or _held(controls, "right") \
		or _held(controls, "up") or _held(controls, "down") \
		or _held(controls, "jump") or _held(controls, "dash")

	var input := _axis(controls, "left", "right")
	if _lock <= 0.0:
		input = _axis(controls, "left", "right")

	if _pressed(controls, "jump_pressed"):
		_buffer = JUMP_BUFFER

	if _try_echo(controls):
		pass
	elif _recover > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION_GROUND * delta)
		velocity.y += GRAVITY_DOWN * gravity_scale * gravity_dir * delta
	elif _pound > 0:
		_tick_pound(delta)
	elif _dash > 0.0:
		_tick_dash(delta)
	elif _footless:
		# Dash reads the real stick — it is the one thing that still answers,
		# and steering it is the whole of the state's movement. Everything that
		# needs legs gets a zero instead: walking, and the charge that turns a
		# stand into a jump.
		_try_dash(input, controls)
		_try_pound(controls)
		_apply_horizontal(0.0, delta)
		_apply_gravity(0.0, delta)
	else:
		# Dash gets asked first, and a pound will not interrupt one. Down is
		# how you aim a dash downward as well as how you pound now, and the
		# pound outranks the dash once it starts — asked the other way round,
		# holding down to dash down would only ever produce a pound.
		_try_dash(input, controls)
		_try_pound(controls)
		_apply_horizontal(input, delta)
		_apply_gravity(input, delta)
		_tick_charge(input, delta)
		_handle_jump(controls)

	velocity += external_force * delta
	external_force = Vector2.ZERO
	move_and_slide()

	if is_on_floor():
		_coyote = COYOTE_TIME
		_chain = 0
		refill_dash()
		if not _was_on_floor:
			_on_land()
		if combo > 0:
			combo_ended.emit(combo)
			combo = 0
			_combo_verbs = 0
	elif _wall_dir != 0 and wall_tile() != "~":
		refill_dash()
	_was_on_floor = is_on_floor()

	_update_sprite(input)
	_update_echo_ghost()
	if networked and locally_controlled and Session.is_client():
		Session.publish_client_state(network_snapshot())


# ------------------------------------------------------------- controls ---

func _read_controls() -> Dictionary:
	if input_provider.is_valid():
		return input_provider.call()
	return {
		"left": Input.is_action_pressed("p_left"),
		"right": Input.is_action_pressed("p_right"),
		"up": Input.is_action_pressed("p_up"),
		"down": Input.is_action_pressed("p_down"),
		"jump": Input.is_action_pressed("p_jump"),
		"dash": Input.is_action_pressed("p_dash"),
		"jump_pressed": Input.is_action_just_pressed("p_jump"),
		"jump_released": Input.is_action_just_released("p_jump"),
		"echo_pressed": Input.is_action_just_pressed("p_echo"),
	}


func _held(controls: Dictionary, key: String) -> bool:
	return bool(controls.get(key, false))


func _pressed(controls: Dictionary, key: String) -> bool:
	return bool(controls.get(key, false))


func _axis(controls: Dictionary, negative: String, positive: String) -> float:
	return float(int(_held(controls, positive)) - int(_held(controls, negative)))


func network_snapshot() -> Dictionary:
	var charge_ratio := _network_charge if client_authority else clampf(_charge / CHARGE_TIME, 0.0, 1.0)
	return {
		"peer_id": peer_id,
		"x": position.x,
		"y": position.y,
		"vx": velocity.x,
		"vy": velocity.y,
		"alive": alive,
		"frozen": frozen,
		"dash": has_dash,
		"facing": facing,
		"anim": _network_anim if client_authority else _sprite_key,
		"charge": charge_ratio,
		"wall": _network_wall_dir if client_authority else _wall_dir,
		"dashing": _dash > 0.0,
	}


func apply_network_snapshot(snapshot: Dictionary) -> void:
	var target := Vector2(float(snapshot.get("x", position.x)), float(snapshot.get("y", position.y)))
	if locally_controlled and Session.is_client():
		# The local client already simulated this player. Only host-owned states
		# such as death and freeze are accepted back; position stays responsive.
		var was_alive := alive
		alive = bool(snapshot.get("alive", alive))
		# The local door tween begins before the host's next snapshot. Keep it
		# frozen so an older host snapshot cannot reveal the player again.
		frozen = true if _door_entering else bool(snapshot.get("frozen", frozen))
		if not alive or (not was_alive and alive):
			position = target
			_network_target = target
			velocity = Vector2(float(snapshot.get("vx", velocity.x)), float(snapshot.get("vy", velocity.y)))
		_sync_sprite_visibility()
		return
	if locally_controlled:
		if position.distance_to(target) > 18.0:
			position = target
		else:
			position = position.lerp(target, 0.35)
	else:
		_network_target = target
		_network_age = 0.0
	velocity = Vector2(float(snapshot.get("vx", velocity.x)), float(snapshot.get("vy", velocity.y)))
	alive = bool(snapshot.get("alive", alive))
	frozen = bool(snapshot.get("frozen", frozen))
	has_dash = bool(snapshot.get("dash", has_dash))
	facing = int(snapshot.get("facing", facing))
	_network_anim = _player_animation(str(snapshot.get("anim", _network_anim)))
	_network_charge = clampf(float(snapshot.get("charge", 0.0)), 0.0, 1.0)
	_network_wall_dir = clampi(int(snapshot.get("wall", 0)), -1, 1)
	_apply_network_dash(bool(snapshot.get("dashing", false)))
	_sync_sprite_visibility()


func apply_client_state(snapshot: Dictionary) -> void:
	if not client_authority:
		return
	position = Vector2(float(snapshot.get("x", position.x)), float(snapshot.get("y", position.y)))
	_network_target = position
	_network_age = 0.0
	velocity = Vector2(float(snapshot.get("vx", velocity.x)), float(snapshot.get("vy", velocity.y)))
	alive = bool(snapshot.get("alive", alive))
	frozen = bool(snapshot.get("frozen", frozen))
	has_dash = bool(snapshot.get("dash", has_dash))
	facing = int(snapshot.get("facing", facing))
	_network_anim = _player_animation(str(snapshot.get("anim", _network_anim)))
	_network_charge = clampf(float(snapshot.get("charge", 0.0)), 0.0, 1.0)
	_network_wall_dir = clampi(int(snapshot.get("wall", 0)), -1, 1)
	_apply_network_dash(bool(snapshot.get("dashing", false)))
	_sync_sprite_visibility()


func _apply_network_dash(active: bool) -> void:
	var was_active := _dash > 0.0
	_dash = DASH_TIME if active else 0.0
	if was_active != active:
		dash_changed.emit(active)


func _sync_sprite_visibility() -> void:
	if sprite == null:
		return
	# Once the door tween hid a frozen player, snapshots must not reveal it.
	sprite.visible = alive and (not frozen or sprite.visible)


func _tick_remote(delta: float) -> void:
	_anim += delta
	_network_age = minf(_network_age + delta, 0.10)
	var predicted := _network_target
	if alive and not frozen:
		predicted += velocity * _network_age
	if position.distance_to(predicted) > 28.0:
		position = predicted
	else:
		position = position.lerp(predicted, minf(delta * 20.0, 1.0))
	_update_remote_sprite()


# ----------------------------------------------------------------- pound ---

func _try_pound(controls: Dictionary) -> void:
	if not pound_unlocked:
		return
	if is_on_floor() or _wall_dir != 0:
		return
	if _dash > 0.0:
		return
	# Always the physical down key. Controls never remap with gravity_dir —
	# only what they do to velocity does; the player's own inputs mean the
	# same thing inside a flip zone as everywhere else.
	if not _held(controls, "down"):
		return
	if _in_zone(no_pound_zone_at):
		return

	_found("pound")
	_pound = 1
	_pound_hang = POUND_HANG
	_pound_dir = gravity_dir
	_buffer = 0.0
	velocity = Vector2.ZERO
	_squash(Vector2(0.6, 1.4))
	Audio.play_varied("pound")


## The falling half sets velocity to a fixed POUND_SPEED every tick — unlike
## everywhere else, nothing here lets normal deceleration carry the player
## through a gravity flip encountered mid-plunge. So the plunge is committed
## to _pound_dir, the direction it started in, and simply ignores a flip it
## meets on the way down. Reading the live gravity_dir instead reversed the
## plunge the instant it grazed a zone edge, firing it back across that same
## edge at the same fixed speed, forever.
##
## Cancelling on a flip is no better, and is what "hold down near a zone"
## used to hit: the cancel drops the player mid-air still carrying
## POUND_SPEED, they cross back out, and the held key re-arms the pound —
## a ping-pong at exactly ±POUND_SPEED that never settles. Committing
## outright ends it, because a committed plunge always terminates: it runs
## until it hits something.
##
## Which is why landing is floor *or* ceiling. is_on_floor() alone is a
## statement about up_direction, and up_direction is the thing a flip just
## changed — plunging "down" under inverted gravity ends on what physics now
## calls a ceiling, and a pound that only ever watched for a floor would
## grind into that surface at POUND_SPEED and never land at all.
func _tick_pound(delta: float) -> void:
	if _pound == 1:
		_pound_hang -= delta
		velocity = Vector2.ZERO
		if _pound_hang <= 0.0:
			_pound = 2
		return

	velocity = Vector2(0.0, POUND_SPEED * _pound_dir)
	if fx != null and randf() < 0.6:
		fx.emit(_fx_at(Vector2(0, -4 * _pound_dir)), 1, Palette.CYAN_MID, 26.0,
			Vector2.UP * _pound_dir, 0.7, 0.2, 40.0)

	if is_on_floor() or is_on_ceiling():
		_land_pound()


func _land_pound() -> void:
	_pound = 0
	_recover = POUND_RECOVER
	_chain = 0
	_enter_footless()
	refill_dash()
	velocity = Vector2.ZERO
	_squash(Vector2(1.5, 0.5))
	Audio.play("stomp")
	if fx != null:
		fx.dust(_fx_at(Vector2(0, HEIGHT * 0.5 * gravity_dir)), Palette.CYAN, 14)
	visual_event.emit("pound_land", _fx_at(Vector2(0, HEIGHT * 0.5 * gravity_dir)), Vector2.DOWN * gravity_dir)
	# The level owns what a landing hits — blocks, slimes, bats. It knows where
	# they all are; the player only knows it hit the ground hard.
	pounded.emit(global_position + Vector2(0, HEIGHT * 0.5 * gravity_dir))


func is_pounding() -> bool:
	return _pound == 2


func is_footless() -> bool:
	return _footless


# --------------------------------------------------------------- footless ---

func _enter_footless() -> void:
	_footless_left = FOOTLESS_TIME
	if _footless:
		return
	_footless = true
	_apply_body_height()


## Only ever called once the timer is spent AND there is somewhere to stand up
## into — see _tick_footless().
func _leave_footless() -> void:
	if not _footless:
		return
	_footless = false
	_footless_left = 0.0
	_apply_body_height()


## The box shrinks off the top: its lower edge sits at the same offset either
## way, so the feet stay put and only the head comes down.
func _apply_body_height() -> void:
	if _shape == null:
		return
	var rect := _shape.shape as RectangleShape2D
	if rect == null:
		return
	var h := FOOTLESS_HEIGHT if _footless else float(HEIGHT)
	rect.size = Vector2(WIDTH, h)
	# Shrinks from the head side, whichever side that currently is: normal
	# gravity, the head is +y-ward of centre already, so this is unchanged;
	# inverted, it flips so the feet — now the +y-ward side — still stay put.
	_shape.position.y = (float(HEIGHT) - h) * 0.5 * gravity_dir


func _tick_footless(delta: float) -> void:
	if not _footless:
		return
	_footless_left = maxf(_footless_left - delta, 0.0)
	if _footless_left <= 0.0 and _has_headroom():
		_leave_footless()


## Whether a full-height body would fit where the short one currently is. Reads
## the grid rather than asking physics: a shape query would have to grow the box
## first to learn that growing it was a mistake.
func _has_headroom() -> bool:
	if not surface_at.is_valid():
		return true
	# Same framing as ground_tile(): surface_at reads Level's own grid, so the
	# node-local position is the one that lines up with it. Mirrored by
	# gravity_dir same as everywhere else — and the row range is taken
	# min-to-max rather than assumed ascending, since inverting gravity_dir
	# flips which end is "top".
	var bottom := position.y + HEIGHT * 0.5 * gravity_dir
	var standing_top := bottom - (float(HEIGHT) - 1.0) * gravity_dir
	var crouched_top := bottom - FOOTLESS_HEIGHT * gravity_dir
	var left := floori((position.x - WIDTH * 0.5 + 1.0) / TILE)
	var right := floori((position.x + WIDTH * 0.5 - 1.0) / TILE)
	var row_a := floori(standing_top / TILE)
	var row_b := floori(crouched_top / TILE)
	for ty in range(mini(row_a, row_b), maxi(row_a, row_b) + 1):
		for tx in range(left, right + 1):
			var ch: String = surface_at.call(tx, ty)
			if ch == "#" or ch == "~" or ch == ">" or ch == "<":
				return false
	return true


func is_dashing() -> bool:
	return _dash > 0.0


## Step 15 — portals. Speed carries through unchanged; only the heading is
## replaced with whatever the exit portal is aimed at. A dash still in
## progress keeps landing on this new heading too, since otherwise it would
## finish travelling toward a direction the exit never pointed at.
func redirect(new_velocity: Vector2) -> void:
	velocity = new_velocity
	if _dash > 0.0:
		_dash_dir = new_velocity.normalized() if new_velocity != Vector2.ZERO else _dash_dir


## A ground pound crossing a portal has nothing sensible to become — it is a
## fixed downward drop, and the exit may not even be pointed down. Cancelling
## it is simpler than inventing a portal-flavoured pound.
func cancel_pound() -> void:
	_pound = 0
	_pound_hang = 0.0


## Mark one verb used this time in the air. A repeat (dash chained off a wall
## touch, say) is not a new count — the point is variety, not spam.
func _add_verb(verb: int) -> void:
	var bit := 1 << verb
	if _combo_verbs & bit:
		return
	_combo_verbs |= bit
	combo += 1
	if combo > 2:
		_found("combo")
	combo_changed.emit(combo, verb)


## Note a first-time move and say so on screen. The callout is the only place
## the codex ever interrupts play, and only ever once per entry.
func _found(entry: String) -> void:
	if not Save.discover(entry):
		return
	if fx != null:
		fx.popup(_fx_at(Vector2(0, -6)), Lang.t("codex.new"), Palette.CYAN, 0.9)


# ------------------------------------------------------------------ dash ---

func _try_dash(input: float, controls: Dictionary) -> void:
	# Holding dash chains automatically whenever a new charge is available.
	if not dash_unlocked or not has_dash or _dash_cool > 0.0 \
			or not _held(controls, "dash"):
		return
	if _in_zone(no_dash_zone_at):
		return

	# Eight-way, taken from whatever is held. Nothing held dashes the way you
	# are already facing, so it never fires into a wall you were backing away
	# from. The "up" key stays the physical up key — same rule as pound — but
	# same as jump, what it produces is gravity-relative: holding it dashes
	# toward whatever "away from the floor" currently means, not toward
	# world -y specifically.
	var vertical := _axis(controls, "up", "down") * gravity_dir
	var dir := Vector2(input, vertical)
	if dir.length_squared() < 0.04:
		dir = Vector2(facing, 0.0)
	_dash_dir = dir.normalized()

	_found("dash")
	_add_verb(Verb.DASH)
	dash_changed.emit(true)
	has_dash = false
	_dash = DASH_TIME
	_lock = DASH_TIME
	velocity = _dash_dir * DASH_SPEED
	facing = -1 if _dash_dir.x < -0.1 else (1 if _dash_dir.x > 0.1 else facing)
	Audio.play_varied("dash")
	_squash(Vector2(1.35, 0.65))
	if fx != null:
		fx.emit(_fx_at(), 8, Palette.CYAN, 90.0, -_dash_dir, 0.9, 0.3, 240.0)
	visual_event.emit("dash", _fx_at(), _dash_dir)


func _tick_dash(delta: float) -> void:
	_dash -= delta
	velocity = _dash_dir * DASH_SPEED
	if fx != null and randf() < 0.7:
		fx.emit(_fx_at(), 1, Palette.CYAN_MID, 18.0, -_dash_dir, 0.6, 0.22, 70.0)
	if _dash <= 0.0:
		# Keep some of it: a dash that dumps you to a standstill kills every
		# chain the move exists to enable.
		velocity = _dash_dir * DASH_SPEED * DASH_KEEP
		# _dash_dir is already gravity-relative from the moment _try_dash()
		# built it (same fix as the axis it was built from), so "aimed
		# roughly at effective up" is this comparison multiplied through by
		# gravity_dir once, same as every other rising/falling check in this
		# file — and the clamp itself gets converted to the local frame and
		# back the same way _apply_gravity()'s wall-slide clamp does.
		if _dash_dir.y * gravity_dir < 0.0:
			velocity.y = maxf(velocity.y * gravity_dir, JUMP_VELOCITY * 0.5) * gravity_dir
		_dash_cool = DASH_COOLDOWN
		dash_changed.emit(false)


## Give the charge back. Ground, walls, stomps, springs and crystals all do.
func refill_dash() -> void:
	has_dash = true


# ------------------------------------------------------------------ echo ---

## Called every physics frame regardless of echo_max — the buffer stays warm
## whether or not the room ever reads it, which is cheaper than branching on
## whether to bother.
func _record_echo() -> void:
	_echo_pos[_echo_head] = global_position
	_echo_vel[_echo_head] = velocity
	_echo_head = (_echo_head + 1) % ECHO_FRAMES


## Returns true the instant it fires, so the physics_process branch above it
## can skip every other state for this one frame — the point of the move is
## that it interrupts anything, dash and pound included.
func _try_echo(controls: Dictionary) -> bool:
	if echo_left <= 0 or not _pressed(controls, "echo_pressed"):
		return false
	# _echo_head already points at the OLDEST sample: _record_echo() just
	# wrote this frame's position over what used to be the oldest one and
	# moved the head past it, so this slot is exactly ECHO_FRAMES-1 frames
	# behind — one second, minus this frame.
	var target := _echo_pos[_echo_head]
	var target_vel := _echo_vel[_echo_head]
	if _overlaps_solid(target):
		# Refusing costs nothing: dying to a correction tool would make the
		# tool the thing players learn to fear.
		Audio.play("menu_back")
		return false

	_found("echo")
	echo_left -= 1
	global_position = target
	velocity = target_vel
	_dash = 0.0
	_dash_cool = 0.0
	dash_changed.emit(false)
	_pound = 0
	_pound_hang = 0.0
	_recover = 0.0
	refill_dash()
	Audio.play("echo")
	if fx != null:
		fx.emit(_fx_at(), 12, Palette.PURPLE, 100.0, Vector2.ZERO, TAU, 0.5, 220.0)
	visual_event.emit("echo", _fx_at(), Vector2.ZERO)
	return true


## Whether a body-sized box at `pos` would sit inside solid terrain. Echoing
## into a wall that closed after the sample was taken (a gate, a phase block
## mid-dash) has to be refused, not resolved by shoving the player somewhere
## move_and_slide() never agreed to.
func _overlaps_solid(pos: Vector2) -> bool:
	if not surface_at.is_valid():
		return false
	var left := floori((pos.x - WIDTH * 0.5 + 1.0) / TILE)
	var right := floori((pos.x + WIDTH * 0.5 - 1.0) / TILE)
	var top := floori((pos.y - HEIGHT * 0.5 + 1.0) / TILE)
	var bottom := floori((pos.y + HEIGHT * 0.5 - 1.0) / TILE)
	for ty in range(top, bottom + 1):
		for tx in range(left, right + 1):
			var ch: String = surface_at.call(tx, ty)
			if ch == "#" or ch == "~" or ch == ">" or ch == "<":
				return true
	return false


## The trail is the sample echoing would use right now, drawn a beat behind
## the player — seeing the destination before spending the use is what keeps
## this a decision instead of a blind stab.
func _update_echo_ghost() -> void:
	if _echo_ghost == null:
		return
	if echo_left <= 0:
		_echo_ghost.visible = false
		return
	_echo_ghost.visible = true
	_echo_ghost.texture = sprite.texture
	_echo_ghost.flip_h = sprite.flip_h
	_echo_ghost.global_position = _echo_pos[_echo_head]


## The ground under your feet decides two things: how fast you can change your
## mind about where you are going, and where "standing still" actually is.
##
## A conveyor moves the target rather than pushing against it. Pushing loses:
## ground friction is 1250 px/s and a belt worth fighting would have to beat
## that every frame, which is a belt that also throws you off ice and stairs.
## Moving the target means standing still on a belt carries you at exactly
## CONVEYOR_PUSH, running with it adds, and running against it subtracts.
func _apply_horizontal(input: float, delta: float) -> void:
	var tile := ground_tile()
	var slippery := tile == "~"

	var carry := 0.0
	if tile == ">":
		carry = CONVEYOR_PUSH
	elif tile == "<":
		carry = -CONVEYOR_PUSH

	var target := input * RUN_SPEED * speed_scale + carry
	var rate := 0.0
	if absf(input) > 0.01:
		if not is_on_floor():
			rate = ACCEL_AIR
		else:
			rate = ACCEL_ICE if slippery else ACCEL_GROUND
	else:
		if not is_on_floor():
			rate = FRICTION_AIR
		else:
			rate = FRICTION_ICE if slippery else FRICTION_GROUND

	velocity.x = move_toward(velocity.x, target, rate * delta)
	if absf(input) > 0.01:
		facing = -1 if input < 0.0 else 1


## Step 22 — gravity zones. Read like ground_tile(): terrain, not an event, so
## it is checked every physics frame rather than fired once on entry.
##
## velocity.y is left exactly as it was on a flip — no reset, no reversal.
## An earlier version flipped its sign to keep the fall's arc "continuous"
## into the new gravity direction, but that aims the player back out through
## the exact edge they just crossed, at full speed, the instant they cross
## it. gravity_dir's own new sign then keeps accelerating them that way, so
## they re-cross, flip back, and repeat every physics frame: stuck
## oscillating right at the seam, unable to act. Zeroing velocity.y instead
## of flipping it has the same failure: with no solid floor right at the
## seam to catch them, they drift back over the boundary a frame or two
## later and flip again, just slower. Leaving velocity.y untouched lets the
## new gravity decelerate whatever fall speed they entered with — the same
## way normal gravity always has — so they keep travelling deeper into the
## zone before it ever reverses them, and the boundary they entered through
## is far behind them by the time it does.
## Same tile lookup gravity zones use, shared by the two Fundo callables.
func _in_zone(cb: Callable) -> bool:
	if not cb.is_valid():
		return false
	var tx := floori(position.x / TILE)
	var ty := floori(position.y / TILE)
	return cb.call(tx, ty)


## A zone's edge is a stable equilibrium — inside, gravity pushes you toward
## the edge and out; outside, it pushes you back in — so anything that drifts
## there parks on it. Read exactly, gravity_dir then alternates every single
## frame, and because half this file is written as `something * gravity_dir`,
## an alternating sign is worse than a wrong one: a jump cancels itself frame
## to frame, is_on_floor() disagrees with itself, and the player is left
## unable to walk, jump or dash back out of the seam they are stuck on.
##
## So neither direction is decided at the edge itself. Flipping needs the
## body a clear GRAV_MARGIN inside the zone, unflipping needs it that far
## outside, and in the band between the two nothing changes at all — the
## player simply keeps the gravity they arrived with. That is what breaks the
## equilibrium rather than merely slowing it down: whatever they keep is
## pushing them off the seam, so they leave it instead of settling onto it.
## GRAV_DWELL then puts a floor under how long any one direction lasts, so
## every `* gravity_dir` downstream means one steady thing for a stretch of
## frames long enough to walk, jump or dash inside.
func _update_gravity_zone(delta: float) -> void:
	_grav_dwell = maxf(_grav_dwell - delta, 0.0)

	if _grav_dwell <= 0.0:
		var was := gravity_dir
		if gravity_dir > 0.0:
			if _zone_at_offset(0.0):
				gravity_dir = -1.0
				_grav_dwell = GRAV_DWELL
		elif not _zone_at_offset(0.0) \
				and not _zone_at_offset(-GRAV_EXIT_MARGIN) \
				and not _zone_at_offset(GRAV_EXIT_MARGIN):
			gravity_dir = 1.0
			_grav_dwell = GRAV_DWELL
		if gravity_dir != was:
			# The footless box hangs off whichever side is currently the head
			# (_apply_body_height()), so its offset is written in terms of
			# gravity_dir. Leave it stale across a flip and the box sits on
			# the wrong side of centre until footless next changes — then it
			# snaps back the full HEIGHT - FOOTLESS_HEIGHT at once, which is
			# how a player tucked against a surface ended up standing four
			# pixels inside it, stuck.
			_apply_body_height()
	# Has to land before move_and_slide() for is_on_floor()/is_on_wall() to
	# read the right surface as "floor" this same frame.
	up_direction = Vector2(0.0, -gravity_dir)


func _zone_at_offset(dy: float) -> bool:
	if not gravity_zone_at.is_valid():
		return false
	var tx := floori(position.x / TILE)
	var ty := floori((position.y + dy) / TILE)
	return gravity_zone_at.call(tx, ty)


## Once you touch a wall you stay on it. Letting go of the stick does not drop
## you — only steering away from the wall, jumping, or running out of wall
## does. Holding a direction to avoid falling is busywork, not difficulty.
func _apply_gravity(input: float, delta: float) -> void:
	# Measured against last frame's contact, before this frame's is recomputed
	# below — so a wall jump thrown the instant contact begins reads _wall_time
	# as exactly 0.0, not one frame late.
	if _wall_dir != 0:
		_wall_time += delta
	else:
		_wall_time = 0.0

	_wall_dir = 0
	if not is_on_floor() and is_on_wall_only():
		var normal := get_wall_normal()
		if absf(normal.x) > 0.7:
			var dir := int(-signf(normal.x))        # 1 = wall is on the right
			var steering_away := absf(input) > 0.01 and signf(input) != float(dir)
			if not steering_away:
				_wall_dir = dir
				_found("wall")

	# "Rising" and "falling" both mean relative to gravity_dir, not to world
	# +y — that is the one substitution this whole function makes.
	var rising := velocity.y * gravity_dir < 0.0
	var g := GRAVITY_UP if rising else GRAVITY_DOWN
	velocity.y += g * gravity_scale * gravity_dir * delta

	var falling := velocity.y * gravity_dir > 0.0
	if _wall_dir != 0 and falling:
		if gravity_dir > 0.0:
			velocity.y = minf(velocity.y, WALL_SLIDE_SPEED)
		else:
			velocity.y = maxf(velocity.y, -WALL_SLIDE_SPEED)
		# Air friction would otherwise peel you off the wall within a few
		# frames, which is what made the slide feel like it kept dropping you.
		velocity.x = _wall_dir * WALL_CLING
		if fx != null and randf() < 0.25:
			fx.emit(_fx_at(Vector2(_wall_dir * 4.0, 2.0 * gravity_dir)), 1,
				Palette.CYAN_DARK, 22.0, Vector2(-_wall_dir, -0.4 * gravity_dir), 0.9, 0.28, 90.0)
	elif gravity_dir > 0.0:
		velocity.y = minf(velocity.y, MAX_FALL * gravity_scale)
	else:
		velocity.y = maxf(velocity.y, -MAX_FALL * gravity_scale)


## Standing still with no input on the ground charges the next jump. It
## survives being airborne on purpose — that is the jump it is paying for,
## not a second one — but resets the instant you touch ground again, charged
## or not, so it can never carry over from one landing into the next.
func _tick_charge(input: float, delta: float) -> void:
	if is_on_floor() and absf(velocity.x) < 4.0 and absf(input) < 0.01:
		var was_full := _charge >= CHARGE_TIME
		_charge = minf(_charge + delta, CHARGE_TIME)
		if fx != null:
			_charge_particle_t += delta
			if _charge_particle_t >= 0.08:
				_charge_particle_t = 0.0
				fx.emit(_fx_at(Vector2(0, HEIGHT * 0.5 * gravity_dir)), 1, Palette.GOLD, 20.0,
					Vector2.UP * gravity_dir, 0.3, 0.3, 40.0)
		if not was_full and _charge >= CHARGE_TIME:
			_found("charge")
			_squash(Vector2(1.15, 0.85))
			Audio.play("charge")
	elif not is_on_floor():
		pass
	else:
		_charge = 0.0
		_charge_particle_t = 0.0


func _handle_jump(controls: Dictionary) -> void:
	if _buffer > 0.0:
		if _coyote > 0.0:
			var boost := CHARGE_BOOST if _charge >= CHARGE_TIME else 1.0
			velocity.y = JUMP_VELOCITY * boost * gravity_dir
			_charge = 0.0
			_buffer = 0.0
			_coyote = 0.0
			Audio.play_varied("jump")
			if fx != null:
				fx.dust(_fx_at(Vector2(0, HEIGHT * 0.5 * gravity_dir)), Palette.CYAN_DARK, 6)
			visual_event.emit("jump", _fx_at(Vector2(0, HEIGHT * 0.5 * gravity_dir)), Vector2.UP * gravity_dir)
		elif _wall_dir != 0:
			# Step 19 — wall boost. Only the horizontal component scales: a
			# taller wall jump would quietly change what every existing room's
			# reachability was built against, but a faster one barely matters
			# in a chimney narrow enough to wall-jump in the first place.
			var perfect := _wall_time <= WALL_WINDOW
			velocity.y = WALL_JUMP.y * gravity_dir
			velocity.x = -_wall_dir * WALL_JUMP.x * (WALL_BOOST if perfect else 1.0)
			facing = -_wall_dir
			_lock = WALL_LOCK
			_buffer = 0.0
			_add_verb(Verb.WALL)
			if perfect:
				Audio.play("wall_jump", 1.18)
			else:
				Audio.play_varied("wall_jump")
			var boost_color := Palette.WHITE if perfect else Palette.CYAN
			if fx != null:
				fx.emit(_fx_at(Vector2(_wall_dir * 4.0, 0.0)), 6 if not perfect else 10,
					boost_color, 70.0, Vector2(-_wall_dir, -0.5 * gravity_dir), 1.2, 0.3, 200.0)
			visual_event.emit("wall_jump", _fx_at(Vector2(_wall_dir * 4.0, 0.0)),
				Vector2(-_wall_dir, -0.5 * gravity_dir))

	# Releasing the button early cuts the rise short.
	if _pressed(controls, "jump_released") and velocity.y * gravity_dir < 0.0:
		velocity.y *= JUMP_CUT


func _on_land() -> void:
	Audio.play_varied("land", 0.1)
	if fx != null:
		fx.dust(_fx_at(Vector2(0, HEIGHT * 0.5 * gravity_dir)), Palette.CYAN_DARK, 7)
	visual_event.emit("land", _fx_at(Vector2(0, HEIGHT * 0.5 * gravity_dir)), Vector2.UP * gravity_dir)
	_squash(Vector2(1.25, 0.75))
	_charge = 0.0


## Particles live in the level's coordinate space, not the player's.
func _fx_at(offset: Vector2 = Vector2.ZERO) -> Vector2:
	return fx.to_local(global_position + offset) if fx != null else global_position + offset


func _squash(to: Vector2) -> void:
	sprite.scale = to
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_sprite(input: float) -> void:
	var key := "player_idle"
	if not is_on_floor():
		if _wall_dir != 0:
			key = "player_wall"
		elif velocity.y * gravity_dir < -20.0:
			key = "player_jump"
		elif velocity.y * gravity_dir > 40.0:
			key = "player_fall"
	elif absf(input) > 0.01 and absf(velocity.x) > 12.0:
		key = "player_run_a" if fmod(_anim * 9.0, 2.0) < 1.0 else "player_run_b"

	if _dash > 0.0:
		key = "player_jump"
	if _pound > 0:
		key = "player_fall"
	# Last word: while the legs are gone the body is the read, whatever else
	# it happens to be doing — including dashing on stumps.
	if _footless:
		key = "player_stump"

	_sprite_key = key
	var charge_ratio := clampf(_charge / CHARGE_TIME, 0.0, 1.0)
	sprite.texture = _player_texture(key, color_index, charge_ratio)
	# Charge brightens the player's own palette. Tinting the complete sprite
	# gold multiplied cyan into green and also erased the chosen multiplayer
	# colour; rebuilding its three colour shades keeps the original hue.
	if _charge > 0.0:
		sprite.modulate = Color.WHITE
	elif has_dash or not dash_unlocked:
		sprite.modulate = Color.WHITE
	else:
		# Spent dash reads as a dimmer sprite — visible without a meter
		# stealing screen from a 480x270 room. Darkened from the original
		# light blue on request; it read as washed out against the sky.
		sprite.modulate = Color(0.45, 0.48, 0.60)
	if _wall_dir != 0:
		sprite.flip_h = _wall_dir > 0
	else:
		sprite.flip_h = facing < 0
	sprite.flip_v = gravity_dir < 0.0


func _update_remote_sprite() -> void:
	_sprite_key = _network_anim
	sprite.texture = _player_texture(_network_anim, color_index, _network_charge)
	if _network_charge > 0.0:
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = Color.WHITE if (has_dash or not dash_unlocked) else Color(0.45, 0.48, 0.60)
	if _network_anim == "player_wall" and _network_wall_dir != 0:
		sprite.flip_h = _network_wall_dir > 0
	else:
		sprite.flip_h = facing < 0


func network_action(kind: String, direction: Vector2) -> void:
	if locally_controlled or sprite == null:
		return
	match kind:
		"dash":
			_squash(Vector2(1.35, 0.65))
		"jump", "wall_jump":
			_squash(Vector2(0.85, 1.15))
		"land", "pound_land":
			_squash(Vector2(1.25, 0.75))
	if absf(direction.x) > 0.1:
		facing = -1 if direction.x < 0.0 else 1


static func _player_animation(key: String) -> String:
	return key if PixelArt.GRIDS.has(key) and key.begins_with("player_") else "player_idle"


static func _player_texture(key: String, index: int, charge: float = 0.0) -> Texture2D:
	# Four visible charge steps avoid rebuilding a texture every physics frame.
	var charge_step := clampi(roundi(clampf(charge, 0.0, 1.0) * 4.0), 0, 4)
	var texture_key := "%s:%d:%d" % [key, posmod(index, PLAYER_COLORS.size()), charge_step]
	if _player_texture_cache.has(texture_key):
		return _player_texture_cache[texture_key]
	var rows: Array = PixelArt.GRIDS.get(key, [])
	if rows.is_empty():
		return PixelArt.tex(key)
	var width := (rows[0] as String).length()
	var image := Image.create_empty(width, rows.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var strength := float(charge_step) / 4.0
	var primary := player_color(index).lerp(Palette.WHITE, 0.18 * strength)
	var light := primary.lerp(Palette.WHITE, 0.45 + 0.15 * strength)
	var dark := primary.darkened(0.45 - 0.12 * strength)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var glyph: String = row[x]
			var pixel: Color = Palette.CHARS.get(glyph, Color(0, 0, 0, 0))
			if glyph == "c":
				pixel = light
			elif glyph == "C":
				pixel = primary
			elif glyph == "D":
				pixel = dark
			if pixel.a > 0.0:
				image.set_pixel(x, y, pixel)
	var texture := ImageTexture.create_from_image(image)
	_player_texture_cache[texture_key] = texture
	return texture


static func player_color(index: int) -> Color:
	return PLAYER_COLORS[posmod(index, PLAYER_COLORS.size())]


static func player_color_name(index: int) -> String:
	return PLAYER_COLOR_NAMES[posmod(index, PLAYER_COLOR_NAMES.size())]


# ------------------------------------------------------------- reactions ---

func spring_bounce() -> void:
	if frozen or not alive:
		return
	_add_verb(Verb.SPRING)
	refill_dash()
	_dash = 0.0
	velocity.y = SPRING_VELOCITY * gravity_dir
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
	_add_verb(Verb.STOMP)
	refill_dash()
	_dash = 0.0
	_pound = 0
	_chain += 1
	var boost := minf(1.0 + float(_chain - 1) * CHAIN_STEP, CHAIN_MAX)
	velocity.y = JUMP_VELOCITY * 0.78 * boost * gravity_dir
	_squash(Vector2(1.3, 0.7))
	Audio.play_varied("stomp")


## What the level is made of, asked one tile at a time. Level hands this over
## before the player enters the tree; without it the player still runs, it just
## treats every surface as ordinary ground.
var surface_at: Callable
## Step 22 — whether a tile sits inside a gravity zone. A separate callable
## from surface_at rather than one more character surface_at() might return:
## Level computes a zone's real extent once, as a rect, precisely so a gem or
## any other entity sitting on one of the zone's own tiles cannot punch a
## grid-shaped hole in it — checking the single character at that tile would
## have exactly that hole built back in.
var gravity_zone_at: Callable
## Fundo backdrops. Each is its own callable, and its own parallel grid on
## Level's side, rather than another gravity_zone_at-style rect: unlike a
## gravity zone these never need to survive a gem punching a hole in them
## (nothing overwrites this grid but the zone itself), so a direct per-tile
## read is enough — no bounding rect to compute.
var no_dash_zone_at: Callable
var no_pound_zone_at: Callable
## Cleared every frame, so two things pushing at once add up for one frame
## rather than accumulating forever.
var external_force := Vector2.ZERO
## Endless modifiers scale these. Jump velocity is deliberately not scaled with
## gravity: heavier gravity against an unchanged jump is the point.
var speed_scale := 1.0
var gravity_scale := 1.0


## The character under the feet, or "." when there is no ground under them.
func ground_tile() -> String:
	if not surface_at.is_valid() or not is_on_floor():
		return "."
	# surface_at reads Level's local grid. The level sits below the HUD, so
	# global_position samples roughly two rows too low and misses ~, > and <.
	# Under inverted gravity the feet — and so the ground — are on the other
	# side of centre, hence the gravity_dir on the offset.
	var tx := floori(position.x / TILE)
	var ty := floori((position.y + (HEIGHT * 0.5 + 2.0) * gravity_dir) / TILE)
	return surface_at.call(tx, ty)


## The tile at the side currently being clung to. Ice is climbable but cannot
## restore a dash, so an ice wall stays a route constraint rather than a refill.
func wall_tile() -> String:
	if not surface_at.is_valid() or _wall_dir == 0:
		return "."
	var tx := floori((position.x + float(_wall_dir) * (WIDTH * 0.5 + 2.0)) / TILE)
	var top := floori((position.y - HEIGHT * 0.5 + 1.0) / TILE)
	var bottom := floori((position.y + HEIGHT * 0.5 - 1.0) / TILE)
	for ty in range(top, bottom + 1):
		if surface_at.call(tx, ty) == "~":
			return "~"
	return surface_at.call(tx, floori(position.y / TILE))


func push(force: Vector2) -> void:
	external_force += force


## Walk into the exit: hand control over and get pulled into the frame.
func enter_door(at: Vector2) -> void:
	if _door_entering:
		return
	_door_entering = true
	frozen = true
	velocity = Vector2.ZERO
	_sprite_key = "player_idle"
	sprite.texture = _player_texture("player_idle", color_index)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", at, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.15, 0.15), 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		if _door_entering and sprite != null:
			sprite.visible = false)


func kill() -> void:
	if not alive or frozen:
		return
	# Only the host may decide a network death. Clients receive it in the next
	# authoritative snapshot instead of killing themselves on a divergent frame.
	if networked and Session.is_client():
		return
	alive = false
	velocity = Vector2.ZERO
	sprite.visible = false
	Audio.play("death")
	if fx != null:
		fx.emit(_fx_at(), 26, Palette.CYAN, 130.0, Vector2.ZERO, TAU, 0.6, 300.0)
		fx.emit(_fx_at(), 10, Palette.WHITE, 90.0, Vector2.ZERO, TAU, 0.4, 260.0)
	visual_event.emit("death", _fx_at(), Vector2.ZERO)
	died.emit()


func respawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	alive = true
	frozen = false
	# Step 22 — every spawn tile is built on ordinary ground, never inside a
	# flip zone, so a respawn always resets the player right side up rather
	# than carrying an inversion across a death.
	gravity_dir = 1.0
	_grav_dwell = 0.0
	up_direction = Vector2.UP
	has_dash = true
	_dash = 0.0
	_pound = 0
	# A respawn puts the legs back regardless of headroom: the spawn point is
	# somewhere a standing player fits by definition, and carrying the state
	# across a death would hand it out for free at the start of the next try.
	_footless = false
	_footless_left = 0.0
	_apply_body_height()
	_recover = 0.0
	_charge = 0.0
	echo_left = echo_max
	_echo_pos.fill(at)
	_echo_vel.fill(Vector2.ZERO)
	_network_charge = 0.0
	_network_wall_dir = 0
	_network_anim = "player_idle"
	_sprite_key = "player_idle"
	_door_entering = false
	combo = 0
	_combo_verbs = 0
	_network_target = at
	_network_age = 0.0
	if sprite != null:
		sprite.visible = true
		sprite.scale = Vector2.ONE


func grab_gem(at: Vector2) -> void:
	gem_grabbed.emit(at)
