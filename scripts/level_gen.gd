class_name LevelGen
extends RefCounted

## The endless mode's room factory. Story rooms stay hand-painted in levels.gd;
## these are assembled at runtime from the same tile characters.
##
## One rule keeps every generated room finishable: a segment always begins and
## ends at floor level, and nothing it paints is wider or taller than a single
## jump. The player clears 61px across and 38px up — about seven tiles and four
## and a half — so pits stop at five tiles, steps at three, and the walkway is
## never interrupted by anything a jump cannot cross.
##
## Rooms are pure functions of (run seed, depth): the same run always produces
## the same rooms, so a restart after a death is the room you just died in.

const COLS := Levels.COLS
const ROWS := Levels.ROWS

const FLOOR := 27               # first solid row of the ground
const STAND := FLOOR - 1        # row a walking player occupies
const START_X := 10             # segments begin past the spawn apron
const END_X := COLS - 10        # and stop before the exit apron
const MAX_GEMS := 3

## Segments that climb the screen instead of hugging the floor.
const TALL := ["climb", "tower", "spring", "stack"]

## The depth each segment first shows up at. Rooms keep introducing something
## the player has not seen for the first twenty or so of them, which is what
## stops a deep run from feeling like the shallow one with bigger numbers.
const UNLOCK := {
	"flat": 0,
	"ledge": 0,
	"platform": 0,
	"pit": 1,
	"slime": 1,
	"stack": 2,
	"spikes": 2,
	"climb": 3,
	"spring": 3,
	"canopy": 4,
	"tower": 5,
	"crumble": 6,
	"saw": 8,
	"bat": 11,
	"airsaw": 10,
	"gauntlet": 13,
	"nest": 16,
	"ferry": 4,
	"beat": 7,
	"vault": 9,
	"crystal": 6,               # not a segment: see _place_crystals()
	"lava": 12,                 # not a segment either: milestone rooms flood
	"ice": 6,
	"belt": 5,
	"retract": 7,
	"elastic": 9,
	"shield": 10,
	"switch": 12,
}

## What each segment is worth in threat. The room is built to a budget of
## these, so difficulty rises with depth instead of with luck.
const THREAT := {
	"flat": 0.0,
	"ledge": 0.0,
	"platform": 0.0,
	"stack": 0.0,
	"climb": 1.0,
	"spring": 1.0,
	"canopy": 1.0,
	"spikes": 2.0,
	"tower": 2.0,
	"pit": 3.0,
	"slime": 3.0,
	"bat": 4.0,
	"crumble": 4.0,
	"saw": 5.0,
	"airsaw": 5.0,
	"gauntlet": 8.0,
	"nest": 7.0,
	"ferry": 2.0,
	"beat": 3.0,
	"vault": 2.0,
	"ice": 2.0,
	"belt": 1.5,
	"retract": 2.5,
	"elastic": 3.0,
	"shield": 4.0,
	"switch": 2.0,
}

## Threat a room aims for. It climbs without ever levelling off, and every
## fifth room is a spike — a landmark you can feel coming.
const THREAT_BASE := 2.0
const THREAT_STEP := 1.35
const THREAT_CEILING := 26.0     # what 40 columns can actually hold
const MILESTONE := 5
const MILESTONE_BONUS := 1.4


## Once a room is as full of threat as 40 columns can hold, difficulty keeps
## climbing through how fast the things in it move.
static func intensity(depth: int) -> float:
	return minf(1.0 + maxf(0.0, float(depth) - 12.0) * 0.035, 2.2)


static func target_threat(depth: int) -> float:
	var t := THREAT_BASE + float(depth) * THREAT_STEP
	if depth > 0 and (depth + 1) % MILESTONE == 0:
		t *= MILESTONE_BONUS
	return minf(t, THREAT_CEILING)


## Build one room. `depth` is 0-based; difficulty ramps with it.
static func generate(run_seed: int, depth: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + depth * 7919
	var target := target_threat(depth)
	# 0..1 knob for how nasty an individual segment paints itself.
	var d := clampf(target / THREAT_CEILING, 0.0, 1.0)

	var g := Levels.blank()
	Levels.rect(g, 0, FLOOR, COLS, ROWS - FLOOR, "#")

	# Every room is guaranteed one structure that uses the height of the
	# screen. Left to chance the mix produces flat corridors too often, and a
	# flat corridor is the one room shape this game has no business shipping.
	var tall: String = TALL[rng.randi() % TALL.size()]
	var tall_at := rng.randi_range(0, 2)
	if int(UNLOCK[tall]) > depth:
		tall = ""

	var spots: Array[Vector2i] = []
	var threat := 0.0
	var x := START_X
	var previous := ""
	var placed := 0

	while x < END_X:
		var room := END_X - x
		if room < 5:
			break
		var kind := _pick(rng, depth, previous, room, target - threat, room, target)
		if not tall.is_empty() and placed >= tall_at and int(WIDTHS[tall]) <= room \
				and int(UNLOCK[tall]) <= depth:
			kind = tall
			tall = ""
		x += _paint(g, rng, kind, x, room, d, spots)
		threat += float(THREAT[kind])
		previous = kind
		placed += 1

	threat += _top_up(g, rng, depth, target - threat, spots)

	Levels.put(g, 4, STAND, "P")
	Levels.put(g, COLS - 6, STAND, "X")
	_place_crystals(g, rng, depth)
	_scatter_gems(g, spots)
	_place_secret(g, rng, depth)
	_flood_milestone(g, depth)

	# "name" here is finished text rather than a key. Lang.t() hands back
	# anything it does not recognise, so the screens that translate story room
	# names print these through unchanged.
	return {
		"name": Lang.tf("endless.room", [depth + 1]),
		"hint": Lang.t("endless.hint") if depth == 0 else "",
		"intensity": intensity(depth),
		"threat": threat,          # what the room actually came out weighing
		"par": 12.0 + threat * 1.4 + float(depth) * 0.4,
		"rows": Levels.bake(g),
	}


# ------------------------------------------------------------ segment pick ---

## Narrowest span each segment can be painted into.
const WIDTHS := {
	"flat": 4,
	"pit": 8,
	"spikes": 6,
	"ledge": 7,
	"platform": 8,
	"slime": 6,
	"spring": 8,
	"canopy": 7,
	"climb": 17,
	"stack": 10,
	"tower": 10,
	"crumble": 9,
	"saw": 9,
	"bat": 8,
	"airsaw": 9,
	"gauntlet": 13,
	"nest": 11,
	"ferry": 11,
	"beat": 12,
	"vault": 9,
	"ice": 8,
	"belt": 6,
	"retract": 6,
	"elastic": 7,
	"shield": 8,
	"switch": 10,
}


## Taste weight per kind, before the budget has its say. This only decides
## which of two equally threatening segments turns up more often.
const TASTE := {
	"flat": 1.0,
	"pit": 1.6,
	"spikes": 1.2,
	"ledge": 1.2,
	"platform": 1.2,
	"slime": 1.6,
	"spring": 2.0,
	"canopy": 1.0,
	"climb": 2.2,
	"stack": 1.8,
	"tower": 1.6,
	"crumble": 1.8,
	"saw": 1.8,
	"bat": 1.8,
	"airsaw": 2.0,
	"gauntlet": 2.2,
	"nest": 2.0,
	"ferry": 2.0,
	"beat": 1.8,
	"vault": 1.6,
	"ice": 1.6,
	"belt": 1.4,
	"retract": 1.5,
	"elastic": 1.8,
	"shield": 1.6,
	"switch": 1.4,
}


## Choose the next segment. `deficit` is the threat still owed, `span` the
## columns left: together they say how hard this one slot has to pull, and the
## pick is pulled towards the kind that carries that much.
static func _pick(rng: RandomNumberGenerator, depth: int, previous: String, room: int,
		deficit: float, span: int, target: float) -> String:
	var slots := maxi(1, span / 9)
	var need := deficit / float(slots)

	var weights := {}
	var total := 0.0
	var pool: Array[String] = []

	for kind: String in TASTE.keys():
		if int(WIDTHS[kind]) > room or int(UNLOCK[kind]) > depth:
			continue
		# Overshooting is what made deep rooms swing between trivial and
		# brutal: one segment worth more than the whole remaining budget is
		# simply not on the table. Past the budget only calm shapes are.
		# How far past the budget a single segment may push. Generous in a deep
		# room, where 3 points is small change; strict in an early one, where
		# it would double the difficulty of the room.
		if float(THREAT[kind]) > maxf(deficit, 0.0) + minf(3.0, target * 0.35):
			continue
		# And a room that still owes a lot cannot afford to spend half its
		# floor on a wide, harmless staircase.
		if int(WIDTHS[kind]) >= 10 and float(THREAT[kind]) < need - 1.5:
			continue
		var w: float = float(TASTE[kind])
		# The closer a kind sits to the threat still owed, the likelier it is.
		w /= 1.0 + absf(float(THREAT[kind]) - need)
		# Never the same trick twice in a row.
		if kind == previous:
			w *= 0.2
		weights[kind] = w
		total += w
		pool.append(kind)

	if pool.is_empty():
		return "flat"

	var roll := rng.randf() * total
	for kind in pool:
		roll -= float(weights[kind])
		if roll <= 0.0:
			return kind
	return pool[pool.size() - 1]


## Segments are coarse, so a room can come in under budget. Sprinkle single
## hazards into whatever clear floor is left until it does not.
##
## Never add 'g' or 'G' here. Gates only ever come from _switch(), which always
## paints the button in the same breath — a gate with no switch in the room is
## a wall with no door, and _top_up() has no way to guarantee it painted one.
static func _top_up(g: Array, rng: RandomNumberGenerator, depth: int, deficit: float,
		spots: Array[Vector2i]) -> float:
	var added := 0.0

	# First pass: whole patrols, which need a stretch of clear ground. Capped,
	# because a floor lined end to end with hazards is not a harder room, it is
	# a flatter one.
	var floor_adds := 0
	var tries := 0
	while added < deficit - 1.0 and tries < 60 and floor_adds < 2:
		tries += 1
		floor_adds += 1
		var x := rng.randi_range(START_X, END_X - 3)
		if not _clear_floor(g, x, 3):
			continue
		if depth >= 1 and rng.randf() < 0.6:
			Levels.put(g, x + 1, STAND, "S")
			added += 3.0
		elif depth >= 2:
			Levels.rect(g, x + 1, STAND, 2, 1, "^")
			added += 2.0
		else:
			spots.append(Vector2i(x + 1, STAND - 2))
			added += 1.0

	# Second pass: single spikes, and not only on the floor — anything the
	# player can stand on will hold one. A dense room reaches its budget this
	# way instead of quietly coming in soft, and the hazards end up spread
	# over the structures rather than all along the ground.
	if depth < 2:
		return added
	# A sky full of bats is its own kind of samey, so they are rationed.
	var bats := 0
	tries = 0
	while added < deficit and tries < 200:
		tries += 1
		var x := rng.randi_range(START_X, END_X - 1)
		# A bat needs no ledge, which is exactly why it can still be added to a
		# room whose floor and platforms are already full.
		if depth >= int(UNLOCK["bat"]) and bats < 2 and added + 4.0 <= deficit \
				and rng.randf() < 0.35:
			var by := rng.randi_range(STAND - 6, STAND - 3)
			if _clear_air(g, x, by):
				Levels.put(g, x, by, "B")
				bats += 1
				added += 4.0
				continue
		var y := rng.randi_range(4, STAND)
		if not _clear_perch(g, x, y):
			continue
		# Ground level already had its share in the first pass.
		if y == STAND:
			floor_adds += 1
			if floor_adds > 3:
				continue
		Levels.put(g, x, y, "^")
		added += 1.0

	return added


## True when a single spike can stand at (x, y): something to stand on below,
## air above, and no spike already touching it left or right.
static func _clear_perch(g: Array, x: int, y: int) -> bool:
	if x < 1 or x >= COLS - 1 or y < 2 or y >= ROWS - 1:
		return false
	if not (g[y + 1][x] in ["#", "-"]):
		return false
	if g[y][x] != "." or g[y - 1][x] != ".":
		return false
	if g[y][x - 1] == "^" or g[y][x + 1] == "^":
		return false
	return true


## Open air with open air around it: room for something that flies.
static func _clear_air(g: Array, x: int, y: int) -> bool:
	if x < 2 or x >= COLS - 2 or y < 2 or y >= ROWS - 1:
		return false
	for i in range(x - 2, x + 3):
		for j in range(y - 1, y + 2):
			if g[j][i] != ".":
				return false
	return true


## True when `w` columns from `x` are plain walkable ground with clear air.
## The span checked runs one column wider on each side, so a hazard dropped in
## here can never butt up against one a segment already placed and grow a run
## longer than a jump can clear.
static func _clear_floor(g: Array, x: int, w: int) -> bool:
	for i in range(x - 1, x + w + 1):
		if i < 1 or i >= COLS - 1:
			return false
		if g[FLOOR][i] != "#" or g[STAND][i] != "." or g[STAND - 1][i] != ".":
			return false
	return true


# ---------------------------------------------------------------- painting ---

## Paint one segment starting at column `x`. Returns the columns it consumed.
static func _paint(g: Array, rng: RandomNumberGenerator, kind: String, x: int,
		room: int, d: float, spots: Array[Vector2i]) -> int:
	match kind:
		"pit":
			return _pit(g, rng, x, room, d, spots)
		"spikes":
			return _spikes(g, x, room, d, spots)
		"ledge":
			return _ledge(g, rng, x, room, spots)
		"platform":
			return _platform(g, rng, x, room, spots)
		"slime":
			return _slime(g, rng, x, room, d, spots)
		"spring":
			return _spring(g, rng, x, room, spots)
		"canopy":
			return _canopy(g, rng, x, room, spots)
		"climb":
			return _climb(g, rng, x, room, spots)
		"stack":
			return _stack(g, rng, x, room, spots)
		"tower":
			return _tower(g, rng, x, room, spots)
		"crumble":
			return _crumble(g, rng, x, room, d, spots)
		"saw":
			return _saw(g, rng, x, room, spots)
		"bat":
			return _bat(g, rng, x, room, spots)
		"airsaw":
			return _airsaw(g, rng, x, room, spots)
		"gauntlet":
			return _gauntlet(g, rng, x, room, d, spots)
		"nest":
			return _nest(g, rng, x, room, spots)
		"ferry":
			return _ferry(g, rng, x, room, d, spots)
		"beat":
			return _beat(g, rng, x, room, d, spots)
		"vault":
			return _vault(g, rng, x, room, spots)
		"ice":
			return _ice(g, rng, x, room, d, spots)
		"belt":
			return _belt(g, rng, x, room, d, spots)
		"retract":
			return _retract(g, rng, x, room, d, spots)
		"elastic":
			return _elastic(g, rng, x, room, spots)
		"shield":
			return _shield(g, rng, x, room, spots)
		"switch":
			return _switch(g, rng, x, room, spots)
		_:
			return _flat(g, rng, x, room, spots)


static func _flat(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(4, 6), room)
	spots.append(Vector2i(x + w / 2, STAND - 2))
	return w


## A bed of spikes under a gap in the floor. Five tiles is the widest it gets,
## which is a comfortable jump short of the 7.6 tiles a run-up buys.
static func _pit(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var pw := clampi(3 + roundi(d * 2.0), 3, 5)
	var w := pw + 4
	if w > room:
		return _flat(g, rng, x, room, spots)

	Levels.rect(g, x + 2, FLOOR, pw, 3, ".")
	Levels.rect(g, x + 2, FLOOR + 3, pw, 1, "^")

	if rng.randf() < 0.45:
		# A thin slab over the pit: cross on top or hop the gap, both work.
		_soft_rect(g, x + 2, FLOOR - 4, pw, 1, "-")
		spots.append(Vector2i(x + 2 + pw / 2, FLOOR - 6))
	else:
		spots.append(Vector2i(x + 2 + pw / 2, FLOOR - 3))
	return w


static func _spikes(g: Array, x: int, room: int, d: float, spots: Array[Vector2i]) -> int:
	var sw := clampi(2 + roundi(d * 1.4), 2, 3)
	var w := sw + 4
	if w > room:
		return mini(4, room)
	Levels.rect(g, x + 2, STAND, sw, 1, "^")
	spots.append(Vector2i(x + 2 + sw / 2, STAND - 3))
	return w


## A block you step up onto and back down from. Three tiles is the tallest,
## well under the 4.7 tile jump.
static func _ledge(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(7, 9), room)
	var h := rng.randi_range(2, 3)
	var bw := w - 4
	Levels.rect(g, x + 2, FLOOR - h, bw, h, "#")
	spots.append(Vector2i(x + 2 + bw / 2, FLOOR - h - 2))
	return w


## A floating shelf with the gem on it. Solid or one-way, chosen by coin flip.
static func _platform(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(8, 10), room)
	var pw := w - 4
	var py := FLOOR - rng.randi_range(3, 4)
	_soft_rect(g, x + 2, py, pw, 1, "#" if rng.randf() < 0.5 else "-")
	spots.append(Vector2i(x + 2 + pw / 2, py - 2))
	return w


static func _slime(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(6, 9), room)
	Levels.put(g, x + 2, STAND, "S")
	if d > 0.5 and w >= 8:
		Levels.put(g, x + w - 3, STAND, "S")
	spots.append(Vector2i(x + w / 2, STAND - 2))
	return w


## A spring under a one-way tier. Solid ground over a spring is a dead end, so
## the tier it fires into is always a slab.
static func _spring(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(8, 10), room)
	var jx := x + w / 2
	Levels.put(g, jx, STAND, "J")
	var py := FLOOR - rng.randi_range(9, 13)
	_soft_rect(g, jx - 2, py, 5, 1, "-")
	spots.append(Vector2i(jx, py - 2))
	return w


## A ceiling slab with spikes hanging off it, held just out of jump reach:
## it punishes a panicked jump, never the route along the floor.
static func _canopy(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(7, 9), room)
	var cy := FLOOR - rng.randi_range(8, 10)
	_soft_rect(g, x + 1, cy, w - 2, 2, "#")
	for i in range(x + 2, x + w - 2):
		if rng.randf() < 0.5:
			_soft_put(g, i, cy + 2, "v")
	spots.append(Vector2i(x + w / 2, STAND - 2))
	return w


## A staircase of thin slabs climbing to the top of the screen. Three rows up
## and four across per step keeps every hop inside a normal jump, and the floor
## underneath stays walkable, so the climb is a detour for gems and never a gate.
static func _climb(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var steps := rng.randi_range(3, 5)
	var w := steps * 4 + 5
	if w > room:
		return _platform(g, rng, x, room, spots)

	var y := FLOOR - 3
	var sx := x + 2
	for i in steps:
		_soft_rect(g, sx, y, 4, 1, "-")
		spots.append(Vector2i(sx + 1, y - 2))
		sx += 4
		y -= 3
	return w


## Two shelves, the upper one reachable from the lower. Cheap height in half
## the space a climb needs.
static func _stack(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(10, 12), room)
	var pw := w - 5
	var low := FLOOR - rng.randi_range(3, 4)
	var high := low - rng.randi_range(3, 4)
	_soft_rect(g, x + 2, low, pw, 1, "-")
	_soft_rect(g, x + 3, high, pw - 2, 1, "#" if rng.randf() < 0.4 else "-")
	spots.append(Vector2i(x + 3 + pw / 2, high - 2))
	spots.append(Vector2i(x + 2 + pw / 2, low - 2))
	return w


## Two spring launches stacked, the way the story's spring tower does it: the
## floor spring throws you onto the first slab, and the spring standing on that
## slab throws you through the second. Every tier above a spring is one-way,
## because solid ground over a spring is a dead end.
static func _tower(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(10, 12), room)
	var jx := x + w / 2

	Levels.put(g, jx, STAND, "J")
	var first := FLOOR - rng.randi_range(8, 10)
	_soft_rect(g, jx - 3, first, 7, 1, "-")
	_soft_put(g, jx - 1, first - 1, "J")
	spots.append(Vector2i(jx + 2, first - 2))

	var second := first - rng.randi_range(8, 10)
	_soft_rect(g, jx - 3, second, 7, 1, "-")
	spots.append(Vector2i(jx, second - 2))
	return w


## A bridge of crumbling tiles over a spike pit. The bridge is never wider
## than a jump, so even a player who lets all of it fall can still cross.
static func _crumble(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var pw := clampi(3 + roundi(d * 2.0), 3, 5)
	var w := pw + 4
	if w > room:
		return _pit(g, rng, x, room, d, spots)

	Levels.rect(g, x + 2, FLOOR, pw, 3, ".")
	Levels.rect(g, x + 2, FLOOR + 3, pw, 1, "^")
	Levels.rect(g, x + 2, FLOOR, pw, 1, "c")
	spots.append(Vector2i(x + 2 + pw / 2, FLOOR - 3))
	return w


## A pen with a blade in it. Two posts keep the saw inside and give the player
## something to stand on while they read its timing; the floor of the pen is
## intact, so crossing it on foot is always an option.
static func _saw(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(9, 10), room)
	Levels.rect(g, x + 1, FLOOR - 2, 1, 2, "#")
	Levels.rect(g, x + w - 2, FLOOR - 2, 1, 2, "#")
	Levels.put(g, x + w / 2, STAND, "W")
	spots.append(Vector2i(x + w / 2, STAND - 4))
	return w


## A blade patrolling a slab in mid-air. The floor underneath stays clear, so
## this is threat that lives in the part of the room a walker never visits —
## the reason deep rooms do not collapse into a spiked corridor.
static func _airsaw(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(9, 11), room)
	var pw := w - 3
	var py := FLOOR - rng.randi_range(4, 5)
	_soft_rect(g, x + 1, py, pw, 1, "-")
	_soft_put(g, x + 1 + pw / 2, py - 1, "W")
	spots.append(Vector2i(x + 1 + pw / 2, py - 3))
	return w


## A bat over open ground. It owns the air the player jumps through, and it is
## the one flying thing you are allowed to land on.
static func _bat(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(8, 11), room)
	Levels.put(g, x + w / 2, STAND - 4, "B")
	spots.append(Vector2i(x + w / 2, STAND - 3))
	return w


## Late-game compound: a crumbling bridge over spikes with a ceiling of
## hanging spikes above it, and something waiting on the far side. Deep rooms
## need segments that are worth a lot per column, or the budget ends up spread
## as a carpet along the floor.
static func _gauntlet(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var pw := clampi(4 + roundi(d), 4, 5)
	var w := pw + 8
	if w > room:
		return _crumble(g, rng, x, room, d, spots)

	Levels.rect(g, x + 2, FLOOR, pw, 3, ".")
	Levels.rect(g, x + 2, FLOOR + 3, pw, 1, "^")
	Levels.rect(g, x + 2, FLOOR, pw, 1, "c")

	# Low ceiling over the bridge: no jumping your way out of the timing.
	var cy := FLOOR - 6
	_soft_rect(g, x + 1, cy, pw + 2, 1, "#")
	for i in range(x + 2, x + 2 + pw):
		if rng.randf() < 0.6:
			_soft_put(g, i, cy + 1, "v")

	Levels.put(g, x + pw + 5, STAND, "S")
	spots.append(Vector2i(x + 2 + pw / 2, FLOOR - 3))
	return w


## Two bats over a spiked floor: the ground is not an option and the air is
## already taken.
static func _nest(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(11, 13), room)
	Levels.rect(g, x + 3, STAND, mini(3, w - 6), 1, "^")
	Levels.put(g, x + 3, STAND - 5, "B")
	Levels.put(g, x + w - 4, STAND - 3, "B")
	spots.append(Vector2i(x + w / 2, STAND - 4))
	return w


## A slab that ferries you over a spiked pit. The pit stays inside a jump, so
## missing the ferry costs time rather than the room.
static func _ferry(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var pw := clampi(3 + roundi(d * 2.0), 3, 5)
	var w := mini(pw + 6, room)
	Levels.rect(g, x + 2, FLOOR, pw, 3, ".")
	Levels.rect(g, x + 2, FLOOR + 3, pw, 1, "^")
	# Orbits are deliberately not generated here. Their radius is measured
	# against whatever air surrounds them, and nothing in the generator can
	# prove the circle does not sweep into terrain on the diagonal — a slab
	# that ends up pinned turns the segment into a room with no way across.
	# The three campaign rooms teach the mechanic on hand-checked geometry.
	var vertical := rng.randf() < 0.35
	_soft_rect(g, x + 2, FLOOR - rng.randi_range(3, 4), 3, 1, "n" if vertical else "m")
	spots.append(Vector2i(x + 2 + pw / 2, FLOOR - 6))
	return w


## A run of blocks keeping time over a pit. Neighbours alternate phase, so
## there is always one about to arrive.
static func _beat(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var pw := clampi(4 + roundi(d), 4, 5)
	var w := mini(pw + 7, room)
	Levels.rect(g, x + 2, FLOOR, pw, 3, ".")
	Levels.rect(g, x + 2, FLOOR + 3, pw, 1, "^")

	var flip := rng.randf() < 0.5
	var bx := x + 2
	while bx < x + 2 + pw:
		_soft_rect(g, bx, FLOOR, mini(2, x + 2 + pw - bx), 1, "T" if flip else "t")
		flip = not flip
		bx += 3
	spots.append(Vector2i(x + 2 + pw / 2, STAND - 3))
	return w


## Dash crystals, once the run is deep enough that a second dash is worth
## routing around. They go in open air above the walkway, where they turn a
## gap into a choice rather than a wait.
static func _place_crystals(g: Array, rng: RandomNumberGenerator, depth: int) -> void:
	if depth < int(UNLOCK["crystal"]):
		return
	var wanted := 1 if depth < 14 else 2
	var placed := 0
	var tries := 0
	while placed < wanted and tries < 60:
		tries += 1
		var x := rng.randi_range(START_X, END_X - 1)
		var y := rng.randi_range(STAND - 6, STAND - 2)
		if not _clear_air(g, x, y):
			continue
		Levels.put(g, x, y, "d")
		placed += 1


## A gem sealed under breakable ground, with spikes flanking the lid. The
## floor route is untouched — this is a detour that costs a pound, not a wall.
static func _vault(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(9, 11), room)
	var lid := x + 3
	Levels.rect(g, lid, FLOOR, 3, 1, "k")
	Levels.rect(g, lid, FLOOR + 1, 3, 2, ".")
	spots.append(Vector2i(lid + 1, FLOOR + 2))
	if rng.randf() < 0.6:
		Levels.put(g, lid - 1, STAND, "^")
		Levels.put(g, lid + 3, STAND, "^")
	return w


## A plate of ice in the middle of the path. No threat by itself, but encodes
## momentum loss as a spatial problem rather than just a time cost.
static func _ice(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(8, 12), room)
	Levels.rect(g, x, FLOOR, w, 1, "~")
	spots.append(Vector2i(x + w / 2, STAND - 3))
	return w


## A moving belt that pushes the player horizontally. Half the time right (>),
## half the time left (<). With the belt you fly, against it you crawl.
static func _belt(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(6, 10), room)
	var ch := ">" if rng.randf() < 0.55 else "<"
	Levels.rect(g, x, FLOOR, w, 1, ch)
	spots.append(Vector2i(x + w / 2, STAND - 3))
	return w


## A pulse on the ground. Cheap in space and expensive in time — the segment
## that doesn't cost distance, only attention.
static func _retract(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var sw := clampi(2 + roundi(d * 2.0), 2, 4)
	var w := sw + 4
	if w > room:
		return mini(4, room)
	var flip := rng.randf() < 0.5
	Levels.rect(g, x + 2, STAND, sw, 1, "Z" if flip else "z")
	spots.append(Vector2i(x + 2 + sw / 2, STAND - 3))
	return w


## An elastic on clear ground. It is the first segment that hands out height
## for free, so its gem sits where only the bounce can reach it — the reward
## for using the thing rather than walking around it.
static func _elastic(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(7, 10), room)
	Levels.put(g, x + w / 2, STAND, "e")
	spots.append(Vector2i(x + w / 2, STAND - 7))
	return w


## An armoured walker. It needs headroom — the answer is a ground pound, and a
## pound with no run-up is no answer at all — so it never goes under a ceiling.
static func _shield(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(8, 11), room)
	var mid := x + w / 2
	for above in range(1, 5):
		if not _clear_air(g, mid, STAND - above):
			return _flat(g, rng, x, room, spots)
	Levels.put(g, mid, STAND, "E")
	spots.append(Vector2i(mid, STAND - 3))
	return w


## A button and the wall it seals shut. Always painted together for the same
## reason _top_up() must never learn to paint 'g' on its own: a gate with no
## switch in the room is a wall with no door.
static func _switch(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(10, 13), room)
	Levels.put(g, x + 2, STAND, "i")
	Levels.rect(g, x + w - 4, STAND - 3, 1, 4, "g")
	spots.append(Vector2i(x + w / 2, STAND - 4))
	return w


## Every fifth room already spikes in difficulty. Flooding it gives that spike
## a face the player recognises from across the room, instead of it being the
## same room with more things in it.
static func _flood_milestone(g: Array, depth: int) -> void:
	if depth < int(UNLOCK["lava"]) or (depth + 1) % MILESTONE != 0:
		return
	Levels.put(g, COLS / 2, ROWS - 2, "A")


## One secret per room, as high as the room will take it. It never blocks
## anything, so the only thing it costs is the detour.
static func _place_secret(g: Array, rng: RandomNumberGenerator, depth: int) -> void:
	if depth < 3:
		return
	var best := Vector2i(-1, -1)
	for attempt in 80:
		var x := rng.randi_range(START_X, END_X - 1)
		var y := rng.randi_range(3, STAND - 6)
		if not _clear_air(g, x, y):
			continue
		if best.x < 0 or y < best.y:
			best = Vector2i(x, y)
	if best.x >= 0:
		Levels.put(g, best.x, best.y, "O")


# ------------------------------------------------------------------- gems ---

## Take up to MAX_GEMS of the candidate spots, spread across the room so the
## three of them are never bunched into one corner.
static func _scatter_gems(g: Array, spots: Array[Vector2i]) -> void:
	var usable: Array[Vector2i] = []
	for p in spots:
		if p.x > 0 and p.x < COLS - 1 and p.y > 0 and g[p.y][p.x] == ".":
			usable.append(p)
	if usable.is_empty():
		Levels.put(g, COLS / 2, STAND - 2, "o")
		return

	# One gem per third of the room, and inside each third the highest
	# candidate wins — that is what makes the climbs worth taking.
	var wanted := mini(MAX_GEMS, usable.size())
	for i in wanted:
		var lo := (i * usable.size()) / wanted
		var hi := ((i + 1) * usable.size()) / wanted
		var pick: Vector2i = usable[lo]
		for j in range(lo, hi):
			if usable[j].y < pick.y:
				pick = usable[j]
		Levels.put(g, pick.x, pick.y, "o")


# ---------------------------------------------------------------- helpers ---

## Write only onto empty air, so a tall segment can never punch a hole in the
## one next to it.
static func _soft_put(g: Array, x: int, y: int, ch: String) -> void:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return
	if g[y][x] == ".":
		g[y][x] = ch


static func _soft_rect(g: Array, x: int, y: int, w: int, h: int, ch: String) -> void:
	for j in range(y, y + h):
		for i in range(x, x + w):
			_soft_put(g, i, j, ch)
