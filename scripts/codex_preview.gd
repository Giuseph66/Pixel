class_name CodexPreview
extends RefCounted

## Live animation for a codex entry, drawn straight onto the book page.
##
## Every preview uses the real gameplay sprites and moves the way the real
## thing moves — the run cycle is the run cycle, the timed blocks blink before
## they go, the door swirls the way the door in a room swirls. A drawn
## pictogram can only ever say "this is about running"; this shows it.
##
## Motion is parametric, not physical: one time value in, positions out. No
## state, nothing to reset, and the same page looks the same every visit.

const SCALE := 2.0              # player, creatures and blocks
const SCALE_SMALL := 3.0        # gem and crystal, which are tiny sprites


static func draw(ci: CanvasItem, id: String, rect: Rect2, t: float) -> bool:
	var cx := rect.position.x + rect.size.x * 0.5
	var floor_y := rect.position.y + rect.size.y - 14.0

	match id:
		"run": _run(ci, rect, cx, floor_y, t)
		"jump": _jump(ci, rect, cx, floor_y, t)
		"wall": _wall(ci, rect, cx, floor_y, t)
		"stomp": _stomp(ci, rect, cx, floor_y, t)
		"dash": _dash(ci, rect, cx, floor_y, t)
		"pound": _pound(ci, rect, cx, floor_y, t)
		"combo": _combo(ci, rect, cx, floor_y, t)
		"charge": _charge(ci, rect, cx, floor_y, t)

		"slime": _patrol(ci, rect, cx, floor_y, t, "slime_a", "slime_b", 0.45)
		"bat": _bat(ci, rect, cx, floor_y, t)
		"saw": _saw(ci, rect, cx, floor_y, t)

		"gem": _gem(ci, rect, cx, floor_y, t)
		"crystal": _crystal(ci, rect, cx, floor_y, t)

		"door": _door(ci, rect, cx, floor_y, t)
		"spike": _spike(ci, rect, cx, floor_y, t)
		"spring": _spring(ci, rect, cx, floor_y, t)
		"crumble": _crumble(ci, rect, cx, floor_y, t)
		"timed": _timed(ci, rect, cx, floor_y, t)
		"breakable": _breakable(ci, rect, cx, floor_y, t)
		"platform": _platform(ci, rect, cx, floor_y, t)
		_:
			return false
	return true


# ------------------------------------------------------------------ helpers ---

## One sprite, centred, optionally mirrored, faded or squashed. Mirroring goes
## through draw_set_transform because draw_texture_rect has no flip of its own.
static func _spr(ci: CanvasItem, name: String, center: Vector2, scale: float = SCALE,
		flip := false, alpha := 1.0, squash := Vector2.ONE, tint := Color.WHITE) -> void:
	var tex := PixelArt.tex(name)
	var size := Vector2(tex.get_width(), tex.get_height()) * scale * squash
	ci.draw_set_transform(Vector2(roundf(center.x), roundf(center.y)), 0.0,
		Vector2(-1.0 if flip else 1.0, 1.0))
	ci.draw_texture_rect(tex, Rect2(-size * 0.5, size), false, Color(tint.r, tint.g, tint.b, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Sprite standing on the floor line rather than centred on a point.
static func _stand(ci: CanvasItem, name: String, x: float, floor_y: float,
		scale: float = SCALE, flip := false, alpha := 1.0, tint := Color.WHITE) -> void:
	var tex := PixelArt.tex(name)
	_spr(ci, name, Vector2(x, floor_y - tex.get_height() * scale * 0.5), scale, flip, alpha,
		Vector2.ONE, tint)


## A burst timed to one instant in the loop rather than accumulated frame by
## frame the way Fx's particles are. `since` is how long ago that instant was
## (negative or past `life` means nothing draws); position at `since` is worked
## out directly from ballistic motion, so the same phase of the loop always
## looks identical — nothing to seed, nothing to reset.
static func _burst(ci: CanvasItem, origin: Vector2, since: float, life: float, count: int,
		color: Color, speed: float, gravity: float = 260.0, size: float = 1.0,
		spread_from: float = 0.0, spread: float = TAU) -> void:
	if since < 0.0 or since > life:
		return
	var fade := 1.0 - since / life
	var alpha := 1.0 if fade > 0.35 else 0.55
	for i in count:
		# Golden-angle spacing: an even-looking spread with no RNG to seed.
		var angle := spread_from + fmod(float(i) * 2.4, spread) - spread * 0.5
		var pace := 0.55 + 0.45 * fmod(float(i) * 0.618, 1.0)
		var vel := Vector2.RIGHT.rotated(angle) * speed * pace
		var p := origin + vel * since + Vector2(0.0, 0.5 * gravity * since * since)
		ci.draw_rect(Rect2(roundf(p.x), roundf(p.y), size, size),
			Color(color.r, color.g, color.b, color.a * alpha))


## The lit rim the real terrain has, so a preview reads as a piece of a room.
static func _ground(ci: CanvasItem, rect: Rect2, y: float) -> void:
	var x := rect.position.x + 4.0
	var w := rect.size.x - 8.0
	ci.draw_rect(Rect2(x, y, w, 2.0), Palette.CYAN_MID)
	ci.draw_rect(Rect2(x, y + 2.0, w, 2.0), Palette.CYAN_DARK)


## The three-pixel rail from MovingPlatform._bake(), drawn at preview scale.
static func _moving_slab(ci: CanvasItem, center: Vector2, tiles: int = 3) -> void:
	var w := float(tiles * PixelArt.TILE) * SCALE
	var x := roundf(center.x - w * 0.5)
	ci.draw_rect(Rect2(x, center.y, w, SCALE), Palette.CYAN_MID)
	ci.draw_rect(Rect2(x, center.y + SCALE, w, SCALE), Palette.CYAN_DARK)
	ci.draw_rect(Rect2(x, center.y + SCALE * 2.0, w, SCALE), Palette.OUTLINE)


## Triangle wave in 0..1 with the direction it is travelling.
static func _pingpong(t: float, period: float) -> Array:
	var phase := fmod(t, period * 2.0) / period
	if phase < 1.0:
		return [phase, 1]
	return [2.0 - phase, -1]


static func _cycle(t: float, period: float) -> float:
	return fmod(t, period) / period


# ----------------------------------------------------------------- abilities ---

static func _run(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var span := rect.size.x * 0.5 - 18.0
	var walk := _pingpong(t, 1.6)
	var x: float = cx - span + span * 2.0 * float(walk[0])
	var frame := "player_run_a" if fmod(t * 9.0, 2.0) < 1.0 else "player_run_b"
	_stand(ci, frame, x, floor_y, SCALE, int(walk[1]) < 0)


static func _jump(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var u := _cycle(t, 1.5)
	# Held on the ground for the first slice, then a single arc.
	if u < 0.22:
		_stand(ci, "player_idle", cx, floor_y)
		# The hold phase IS just after landing — the arc wraps back to u=0 the
		# instant it touches down, so "time into the hold" doubles as "time
		# since landing" for free.
		_burst(ci, Vector2(cx, floor_y), u * 1.5, 0.3, 6, Palette.CYAN_DARK, 30.0, 90.0,
			1.0, -PI * 0.5, PI)
		return
	var p := (u - 0.22) / 0.78
	var h := sin(p * PI) * 34.0
	_stand(ci, "player_jump" if p < 0.5 else "player_fall", cx, floor_y - h)


static func _wall(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	# A slab on the right to cling to, painted with the same tile the terrain
	# under a real room uses — the speckle and the outlined edge come from
	# paint_tile() itself, not redrawn by hand here.
	var wall_x := cx + 20.0
	var top := rect.position.y + 8.0
	var tiles := maxi(1, ceili((floor_y - top) / (PixelArt.TILE * SCALE)))
	var strip := PixelArt.wall_strip(tiles)
	ci.draw_texture_rect(strip, Rect2(wall_x, floor_y - tiles * PixelArt.TILE * SCALE,
		PixelArt.TILE * SCALE, tiles * PixelArt.TILE * SCALE), false)

	var u := _cycle(t, 1.8)
	var y := lerpf(top + 18.0, floor_y - 12.0, u)
	# Player sprite is 8px wide at this scale (half-width 8), so the centre has
	# to sit 8px off the wall's left edge to actually touch it — 10px was
	# leaving a visible 2px gap, reading as floating rather than clinging.
	# flip_h is true when the wall is on the right, matching player.gd.
	_spr(ci, "player_wall", Vector2(wall_x - 8.0, y), SCALE, true)

	# A fleck peeling off the wall every third of a second, the same sparse
	# rate player.gd's own 25%-per-frame roll averages out to.
	var since := fmod(t, 0.3)
	_burst(ci, Vector2(wall_x - 4.0, y + 2.0), since, 0.3, 1, Palette.CYAN_DARK, 16.0, 70.0,
		1.0, PI, PI * 0.7)


static func _stomp(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var u := _cycle(t, 1.8)
	var slime_y := floor_y - 8.0 * SCALE * 0.5

	if u < 0.45:
		var p := u / 0.45
		_stand(ci, "slime_a" if fmod(t * 5.0, 2.0) < 1.0 else "slime_b", cx, floor_y)
		_spr(ci, "player_fall", Vector2(cx, lerpf(rect.position.y + 14.0, slime_y - 16.0, p)))
	elif u < 0.6:
		# Contact: the slime goes flat, the player is thrown back up.
		_spr(ci, "slime_b", Vector2(cx, floor_y - 4.0), SCALE, false, 1.0, Vector2(1.4, 0.4))
		_spr(ci, "player_jump", Vector2(cx, slime_y - 18.0))
		_burst(ci, Vector2(cx, slime_y), (u - 0.45) * 1.8, 0.3, 8, Palette.GREEN, 60.0, 200.0,
			1.0, -PI * 0.5, TAU)
	else:
		var p := (u - 0.6) / 0.4
		_spr(ci, "player_jump", Vector2(cx, lerpf(slime_y - 18.0, rect.position.y + 12.0, p)))


static func _dash(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var span := rect.size.x * 0.5 - 16.0
	var u := _cycle(t, 1.5)
	var travel := minf(u / 0.4, 1.0)

	# Three fading afterimages behind the leading sprite: the streak is the
	# whole reason a dash looks different from a run.
	for i in 3:
		var lag := clampf(travel - 0.1 * float(i + 1), 0.0, 1.0)
		_stand(ci, "player_jump", lerpf(cx - span, cx + span, lag), floor_y,
			SCALE, false, 0.3 - 0.07 * float(i))
	_stand(ci, "player_jump", lerpf(cx - span, cx + span, travel), floor_y)

	# Kicked off at the exact instant the streak starts, blown backward against
	# the direction of travel — the same burst player.gd fires from _try_dash.
	_burst(ci, Vector2(cx - span, floor_y - 8.0), u * 1.5, 0.25, 6, Palette.CYAN, 50.0, 160.0,
		1.0, PI, PI * 0.9)


static func _pound(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	var u := _cycle(t, 2.0)
	var block_y := floor_y - 8.0 * SCALE

	if u < 0.4:
		_ground(ci, rect, floor_y)
		_spr(ci, "breakable", Vector2(cx, block_y + 8.0 * SCALE * 0.5))
		_spr(ci, "player_fall", Vector2(cx, lerpf(rect.position.y + 14.0, block_y - 14.0,
			u / 0.4)))
	elif u < 0.52:
		_ground(ci, rect, floor_y)
		_spr(ci, "breakable", Vector2(cx, block_y + 8.0 * SCALE * 0.5), SCALE, false, 0.5)
		_spr(ci, "player_fall", Vector2(cx, block_y - 6.0))
		ci.draw_rect(Rect2(cx - 18.0, block_y + 12.0, 36.0, 2.0), Palette.WHITE)
		_burst(ci, Vector2(cx, block_y + 8.0 * SCALE * 0.5), (u - 0.4) * 2.0, 0.3, 10,
			Palette.FRAME, 70.0, 220.0, 1.0, -PI * 0.5, TAU)
	else:
		# Ground opened: the block is gone and stays gone.
		var gap := 8.0 * SCALE
		ci.draw_rect(Rect2(rect.position.x + 4.0, floor_y, cx - gap * 0.5 - rect.position.x - 4.0,
			2.0), Palette.CYAN_MID)
		ci.draw_rect(Rect2(cx + gap * 0.5, floor_y,
			rect.position.x + rect.size.x - 4.0 - cx - gap * 0.5, 2.0), Palette.CYAN_MID)
		var fall := (u - 0.52) / 0.48
		var sink_y := lerpf(block_y - 6.0, rect.end.y - 9.0, fall)
		var alpha := 0.8 * (1.0 - clampf((fall - 0.72) / 0.28, 0.0, 1.0))
		_spr(ci, "player_fall", Vector2(cx, sink_y), SCALE, false, alpha)


## Three distinct aerial verbs chained before landing — dash, wall, stomp —
## same as level.gd's own _on_combo_changed() popup, same colour grading
## (cyan under 4, gold from 4, this preview never gets there so it never
## needs white). The landing burst is the score cashing in, level.gd's
## _on_combo_ended().
static func _combo(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var wall_x := cx + 40.0
	var land_x := cx - 24.0
	var u := _cycle(t, 3.2)

	if u < 0.22:
		# Verb 1 — dash in from the left, low over the ground.
		var p := u / 0.22
		var x := lerpf(rect.position.x + 14.0, wall_x - 6.0, p)
		for i in 3:
			var lag := clampf(p - 0.12 * float(i + 1), 0.0, 1.0)
			_stand(ci, "player_jump", lerpf(rect.position.x + 14.0, wall_x - 6.0, lag),
				floor_y - 18.0, SCALE, false, 0.3 - 0.07 * float(i))
		_stand(ci, "player_jump", x, floor_y - 18.0)
		if p > 0.92:
			PixelFont.draw_text_centered(ci, "X1", wall_x, floor_y - 60.0, Palette.CYAN, 2)
	elif u < 0.5:
		# Verb 2 — a beat clinging the wall it dashed into.
		var p := (u - 0.22) / 0.28
		var y := lerpf(floor_y - 40.0, floor_y - 14.0, p)
		_spr(ci, "player_wall", Vector2(wall_x, y), SCALE, true)
		if p < 0.2:
			PixelFont.draw_text_centered(ci, "X2", wall_x, floor_y - 60.0, Palette.CYAN,
				2 if p > 0.02 else 1)
	elif u < 0.82:
		# Verb 3 — kicks off the wall onto a slime below.
		var p := (u - 0.5) / 0.32
		var slime_y := floor_y - 8.0 * SCALE * 0.5
		_stand(ci, "slime_a" if fmod(t * 5.0, 2.0) < 1.0 else "slime_b", land_x, floor_y)
		if p < 0.55:
			_spr(ci, "player_fall", Vector2(lerpf(wall_x, land_x, p / 0.55),
				lerpf(floor_y - 14.0, slime_y - 16.0, p / 0.55)))
		else:
			var q := (p - 0.55) / 0.45
			_spr(ci, "player_jump", Vector2(land_x, lerpf(slime_y - 16.0, floor_y - 30.0, q)))
			if q < 0.2:
				PixelFont.draw_text_centered(ci, "X3", land_x, floor_y - 60.0, Palette.CYAN,
					2 if q > 0.02 else 1)
	else:
		# Landing — the chain ends, the score cashes in.
		var p := (u - 0.82) / 0.18
		_stand(ci, "player_idle", land_x, floor_y)
		_burst(ci, Vector2(land_x, floor_y - 4.0), p * 0.58, 0.4, 10, Palette.GOLD, 65.0, 180.0,
			1.0, -PI * 0.5, TAU)


## Held on the ground, the sprite pulling toward gold exactly the way
## player.gd's own _update_sprite() lerps it — then a taller arc than a plain
## jump, the reward for the hold.
static func _charge(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var u := _cycle(t, 2.2)
	if u < 0.38:
		var p := u / 0.38
		var tint := Color.WHITE.lerp(Palette.GOLD, p * 0.7)
		_stand(ci, "player_idle", cx, floor_y, SCALE, false, 1.0, tint)
		if p > 0.9:
			_burst(ci, Vector2(cx, floor_y - 5.0), (p - 0.9) * 3.8, 0.3, 6, Palette.GOLD, 26.0,
				90.0, 1.0, -PI * 0.5, PI)
	else:
		var p := (u - 0.38) / 0.62
		var h := sin(p * PI) * 58.0
		_stand(ci, "player_jump" if p < 0.5 else "player_fall", cx, floor_y - h)
		if p < 0.06:
			_burst(ci, Vector2(cx, floor_y - 5.0), p * 5.0, 0.3, 8, Palette.GOLD, 60.0, 180.0,
				1.0, -PI * 0.5, TAU)


# ----------------------------------------------------------------- creatures ---

## Walks its ledge and turns at the edge, exactly like the real one.
static func _patrol(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float,
		frame_a: String, frame_b: String, rate: float) -> void:
	_ground(ci, rect, floor_y)
	var span := rect.size.x * 0.5 - 16.0
	var walk := _pingpong(t, 2.2)
	var x: float = cx - span + span * 2.0 * float(walk[0])
	var frame := frame_a if fmod(t / rate, 2.0) < 1.0 else frame_b
	_stand(ci, frame, x, floor_y, SCALE, int(walk[1]) > 0)


static func _bat(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var span := rect.size.x * 0.5 - 16.0
	# A slow horizontal sweep with a faster bob on top: the wave the bat flies.
	var x := cx + sin(t * 1.1) * span
	var y := rect.position.y + rect.size.y * 0.42 + sin(t * 2.4) * 9.0
	var frame := "bat_a" if fmod(t * 7.0, 2.0) < 1.0 else "bat_b"
	_spr(ci, frame, Vector2(x, y), SCALE, cos(t * 1.1) < 0.0)


static func _saw(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var span := rect.size.x * 0.5 - 16.0
	var walk := _pingpong(t, 1.9)
	var x: float = cx - span + span * 2.0 * float(walk[0])
	# Spins far faster than it travels, which is what makes it read as a blade.
	var frame := "saw_a" if fmod(t * 14.0, 2.0) < 1.0 else "saw_b"
	_stand(ci, frame, x, floor_y)


# -------------------------------------------------------------- collectibles ---

static func _gem(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var y := floor_y - 26.0 + roundf(sin(t * 3.0) * 3.0)
	_spr(ci, "gem", Vector2(cx, y), SCALE_SMALL)
	# Sparks orbiting the way the pickup burst does.
	for i in 4:
		var phase := t * 2.2 + float(i) * (TAU / 4.0)
		var r := 16.0 + sin(t * 3.0 + float(i)) * 3.0
		var p := Vector2(cos(phase) * r, sin(phase) * r * 0.6)
		ci.draw_rect(Rect2(roundf(cx + p.x), roundf(y + p.y), 2.0, 2.0), Palette.GOLD)


static func _crystal(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var u := _cycle(t, 2.2)
	var y := floor_y - 28.0 + roundf(sin(t * 2.4) * 2.0)
	# Spent for the middle of the cycle, then back: that is the recharge.
	_spr(ci, "crystal" if u < 0.5 else "crystal_used", Vector2(cx, y), SCALE_SMALL)
	if u >= 0.5 and u < 0.56:
		ci.draw_rect(Rect2(cx - 14.0, y - 1.0, 28.0, 2.0), Palette.CYAN)
		_burst(ci, Vector2(cx, y), (u - 0.5) * 2.2, 0.25, 8, Palette.CYAN, 45.0, 0.0,
			1.0, 0.0, TAU)


# -------------------------------------------------------------------- world ---

static func _door(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var tex := PixelArt.tex("door")
	var centre := Vector2(cx, floor_y - tex.get_height() * SCALE * 0.5)
	_spr(ci, "door", centre, SCALE)

	# The same six drifting pixels the real door has inside it.
	for i in 6:
		var phase := t * 1.6 + float(i) * (TAU / 6.0)
		var radius := 1.5 + 1.5 * sin(t * 2.0 + float(i))
		var p := Vector2(roundf(cos(phase) * radius), roundf(sin(phase * 0.8) * (radius + 1.5)))
		ci.draw_rect(Rect2(roundf(centre.x + p.x * SCALE), roundf(centre.y + p.y * SCALE),
			SCALE, SCALE), Palette.PURPLE.lerp(Palette.WHITE, 0.4))


static func _spike(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	for i in 3:
		_stand(ci, "spike", cx + (float(i) - 1.0) * 8.0 * SCALE, floor_y)

	# Cleared, not touched: the hitbox is smaller than it looks.
	var u := _cycle(t, 2.0)
	var span := rect.size.x * 0.5 - 14.0
	var x := lerpf(cx - span, cx + span, u)
	var h := sin(u * PI) * 34.0
	_stand(ci, "player_jump" if u < 0.5 else "player_fall", x, floor_y - h)
	# The arc lands right as u wraps to 0, so early-cycle time is time since
	# the clear landed clean.
	_burst(ci, Vector2(cx - span, floor_y), u * 2.0, 0.25, 5, Palette.CYAN_DARK, 26.0, 90.0,
		1.0, -PI * 0.5, PI * 0.8)


static func _spring(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var u := _cycle(t, 1.7)
	var h := absf(sin(u * PI)) * 44.0
	var fired := h < 5.0
	_stand(ci, "spring_fired" if fired else "spring", cx, floor_y)
	_stand(ci, "player_jump" if u < 0.5 else "player_fall", cx, floor_y - 12.0 - h)
	# Fires at u=0/wrap, same trick as the jump and spike landings.
	_burst(ci, Vector2(cx, floor_y - 6.0), u * 1.7, 0.28, 8, Palette.MAGENTA, 55.0, 140.0,
		1.0, -PI * 0.5, PI * 0.7)


static func _crumble(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var u := _cycle(t, 2.4)
	var block_top := floor_y - 8.0 * SCALE
	var block_centre := Vector2(cx, block_top + 8.0 * SCALE * 0.5)

	if u < 0.3:
		_spr(ci, "crumble", block_centre)
		_stand(ci, "player_idle", cx, block_top)
	elif u < 0.5:
		_spr(ci, "crumble_cracked", block_centre)
		_stand(ci, "player_idle", cx, block_top)
	else:
		# Both fall, the block fading as it goes. Running to the end of the
		# cycle keeps the stage from sitting empty before it loops.
		var p := (u - 0.5) / 0.5
		_spr(ci, "crumble_cracked", block_centre + Vector2(0.0, p * 44.0), SCALE, false,
			maxf(0.0, 1.0 - p))
		_spr(ci, "player_fall", Vector2(cx, block_top - 10.0 + p * 34.0))
		_burst(ci, block_centre, (u - 0.5) * 2.4, 0.3, 6, Palette.GREY_DARK, 40.0, 200.0,
			1.0, -PI * 0.5, PI)


static func _timed(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	# Room 16: two-tile groups alternate t/T, with a full jump timed to the
	# switch. The player never floats over an off block.
	var beat := _cycle(t, 2.3)
	var even_on := beat < 0.5
	var warning := (beat > 0.36 and beat < 0.5) or beat > 0.86
	var block_y := floor_y - 12.0
	var pair_gap := 40.0
	for pair in 3:
		var on := even_on if pair % 2 == 0 else not even_on
		var alpha := 0.45 if on and warning and fmod(t * 18.0, 2.0) < 1.0 else 1.0
		var pair_x := cx + (float(pair) - 1.0) * pair_gap
		for block in 2:
			_spr(ci, "timed_on" if on else "timed_off",
				Vector2(pair_x + (float(block) - 0.5) * 16.0, block_y), SCALE, false, alpha)

	var left_x := cx - pair_gap
	var middle_x := cx
	var foot_y := block_y - 8.0
	if beat < 0.36:
		_stand(ci, "player_idle", left_x, foot_y)
	elif beat < 0.5:
		var p := (beat - 0.36) / 0.14
		var h := sin(p * PI) * 20.0
		_stand(ci, "player_jump" if p < 0.5 else "player_fall",
			lerpf(left_x, middle_x, p), foot_y - h)
	elif beat < 0.86:
		_stand(ci, "player_idle", middle_x, foot_y)
	else:
		var p := (beat - 0.86) / 0.14
		var h := sin(p * PI) * 20.0
		_stand(ci, "player_jump" if p < 0.5 else "player_fall",
			lerpf(middle_x, left_x, p), foot_y - h)


static func _breakable(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	var u := _cycle(t, 2.2)
	var block_centre := Vector2(cx, floor_y - 8.0 * SCALE * 1.5)

	# A wall of three, with the middle one taken out by a pound and put back.
	for i in 3:
		var pos := block_centre + Vector2((float(i) - 1.0) * 8.0 * SCALE, 0.0)
		if i == 1 and u > 0.5:
			continue
		_spr(ci, "breakable", pos)

	if u < 0.42:
		_spr(ci, "player_fall", Vector2(cx, lerpf(rect.position.y + 12.0,
			block_centre.y - 18.0, u / 0.42)))
	elif u < 0.5:
		_spr(ci, "player_fall", Vector2(cx, block_centre.y - 14.0))
		ci.draw_rect(Rect2(cx - 16.0, block_centre.y - 2.0, 32.0, 2.0), Palette.WHITE)
		_burst(ci, block_centre, (u - 0.42) * 2.2, 0.3, 8, Palette.GREY_DARK, 55.0, 210.0,
			1.0, -PI * 0.5, TAU)
	else:
		_spr(ci, "player_fall", Vector2(cx, lerpf(block_centre.y - 14.0, floor_y - 10.0,
			(u - 0.5) / 0.5)))


static func _platform(ci: CanvasItem, rect: Rect2, cx: float, floor_y: float, t: float) -> void:
	_ground(ci, rect, floor_y)
	# Room 18: ferry crosses the pit while a second slab works as a lift.
	var ferry := _pingpong(t, 1.7)
	var ferry_x := lerpf(rect.position.x + 34.0, cx - 16.0, float(ferry[0]))
	var ferry_y := floor_y - 22.0
	_moving_slab(ci, Vector2(ferry_x, ferry_y))
	_stand(ci, "player_idle", ferry_x, ferry_y)

	var lift := _pingpong(t + 0.55, 1.5)
	var lift_y := lerpf(floor_y - 50.0, floor_y - 22.0, float(lift[0]))
	_moving_slab(ci, Vector2(cx + 42.0, lift_y))
