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

## How many rooms it takes to reach full difficulty.
const RAMP := 14.0

## Segments that climb the screen instead of hugging the floor.
const TALL := ["climb", "tower", "spring", "stack"]


## Build one room. `depth` is 0-based; difficulty ramps with it.
static func generate(run_seed: int, depth: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + depth * 7919
	var d := clampf(float(depth) / RAMP, 0.0, 1.0)

	var g := Levels.blank()
	Levels.rect(g, 0, FLOOR, COLS, ROWS - FLOOR, "#")

	# Every room is guaranteed one structure that uses the height of the
	# screen. Left to chance the mix produces flat corridors too often, and a
	# flat corridor is the one room shape this game has no business shipping.
	var tall: String = TALL[rng.randi() % TALL.size()]
	var tall_at := rng.randi_range(0, 2)

	var spots: Array[Vector2i] = []
	var hazards := 0
	var x := START_X
	var previous := ""
	var placed := 0

	while x < END_X:
		var room := END_X - x
		if room < 5:
			break
		var kind := _pick(rng, d, previous, room)
		if not tall.is_empty() and placed >= tall_at and int(WIDTHS[tall]) <= room:
			kind = tall
			tall = ""
		x += _paint(g, rng, kind, x, room, d, spots)
		if kind != "flat":
			hazards += 1
		previous = kind
		placed += 1

	Levels.put(g, 4, STAND, "P")
	Levels.put(g, COLS - 6, STAND, "X")
	_scatter_gems(g, spots)

	# "name" here is finished text rather than a key. Lang.t() hands back
	# anything it does not recognise, so the screens that translate story room
	# names print these through unchanged.
	return {
		"name": Lang.tf("endless.room", [depth + 1]),
		"hint": Lang.t("endless.hint") if depth == 0 else "",
		"par": 12.0 + float(hazards) * 2.0 + float(depth) * 0.4,
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
}


## Weight per segment kind at difficulty `d`. Early rooms are mostly shape,
## late rooms are mostly threat.
static func _weights(d: float) -> Dictionary:
	return {
		"flat": 2.0 - 1.6 * d,
		"pit": 1.0 + 2.0 * d,
		"spikes": 0.6 + 1.6 * d,
		"ledge": 1.4,
		"platform": 1.4,
		"slime": 0.8 + 1.8 * d,
		"spring": 2.2,
		"canopy": 0.5 + 1.0 * d,
		"climb": 2.4,
		"stack": 2.0,
		"tower": 1.8,
	}


static func _pick(rng: RandomNumberGenerator, d: float, previous: String, room: int) -> String:
	var weights := _weights(d)
	var total := 0.0
	var pool: Array[String] = []

	for kind: String in weights.keys():
		if int(WIDTHS[kind]) > room:
			continue
		var w: float = maxf(weights[kind], 0.05)
		# Never the same trick twice in a row.
		if kind == previous:
			w *= 0.25
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
