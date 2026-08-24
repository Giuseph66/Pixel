class_name Levels
extends RefCounted

## The whole game, as data.
##
## Every level is one screen: 60 columns by 32 rows of 8px tiles. Maps are not
## typed out as ASCII art — they are painted with rect/put calls onto a blank
## grid, so a level can never end up with a row of the wrong length, and moving
## a platform is a number edit rather than a character count.
##
## Tile characters, once painted:
##   #  solid terrain          o  gem
##   -  one-way platform       P  player spawn
##   ^  spike, points up       X  exit door (bottom-left tile of the frame)
##   v  spike, points down     S  slime
##   .  empty air              J  spring pad
##   W  saw, patrols its row   B  bat, patrols the air
##   c  crumbling ground, drops a moment after you stand on it
##   d  dash crystal            m  slab that slides sideways
##   t  timed block, on first   n  slab that rides up and down
##   T  timed block, off first  k  breakable block, opens to a ground pound

const COLS := 60
const ROWS := 32


# --------------------------------------------------------------- painting ---
#
# Public because the endless generator in level_gen.gd paints on the same
# grid with the same tile characters.

static func blank() -> Array:
	var grid := []
	for y in ROWS:
		var row := []
		for x in COLS:
			row.append(".")
		grid.append(row)
	# Sealed room: nothing can ever leave the screen.
	for x in COLS:
		grid[0][x] = "#"
		grid[ROWS - 1][x] = "#"
	for y in ROWS:
		grid[y][0] = "#"
		grid[y][COLS - 1] = "#"
	return grid


static func rect(grid: Array, x: int, y: int, w: int, h: int, ch: String) -> void:
	for j in range(y, y + h):
		if j < 0 or j >= ROWS:
			continue
		for i in range(x, x + w):
			if i < 0 or i >= COLS:
				continue
			grid[j][i] = ch


static func put(grid: Array, x: int, y: int, ch: String) -> void:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return
	grid[y][x] = ch


static func puts(grid: Array, points: Array, ch: String) -> void:
	for p: Vector2i in points:
		put(grid, p.x, p.y, ch)


static func bake(grid: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for row: Array in grid:
		var line := ""
		for ch: String in row:
			line += ch
		out.append(line)
	return out


# ----------------------------------------------------------------- levels ---

## Staircase of ledges. Nothing can kill you here.
static func _level_1() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 16, 25, 7, 2, "#")
	rect(g, 27, 22, 8, 5, "#")
	rect(g, 38, 19, 15, 8, "#")
	puts(g, [Vector2i(19, 24), Vector2i(30, 21), Vector2i(44, 18)], "o")
	put(g, 4, 26, "P")
	put(g, 48, 18, "X")
	return bake(g)


## Spiked pits, one-way platforms overhead.
static func _level_2() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	# Each pit is (start column, width): three tiles of air over a bed of spikes.
	for pit: Vector2i in [Vector2i(13, 5), Vector2i(27, 6), Vector2i(43, 5)]:
		var start := pit.x
		var width := pit.y
		rect(g, start, 27, width, 3, ".")
		rect(g, start, 30, width, 1, "^")
	rect(g, 10, 23, 5, 1, "-")
	rect(g, 35, 23, 6, 1, "-")
	rect(g, 17, 20, 6, 1, "#")
	rect(g, 50, 24, 10, 3, "#")
	puts(g, [Vector2i(12, 22), Vector2i(19, 19), Vector2i(37, 22)], "o")
	put(g, 4, 26, "P")
	put(g, 53, 23, "X")
	return bake(g)


## Low ceiling with hanging spikes, spike patches on the floor.
static func _level_3() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 6, 18, 39, 3, "#")
	# Hung where nobody needs to jump: they punish reflex jumping, not routing.
	puts(g, [Vector2i(24, 21), Vector2i(25, 21), Vector2i(28, 21), Vector2i(29, 21)], "v")
	rect(g, 12, 26, 3, 1, "^")
	rect(g, 20, 26, 3, 1, "^")
	rect(g, 34, 26, 3, 1, "^")
	rect(g, 46, 23, 14, 4, "#")
	puts(g, [Vector2i(13, 25), Vector2i(21, 25), Vector2i(35, 25)], "o")
	put(g, 3, 26, "P")
	put(g, 49, 22, "X")
	return bake(g)


## Patrolling slimes on the ground and on two floating platforms.
static func _level_4() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 22, 20, 9, 1, "#")
	rect(g, 10, 23, 9, 1, "#")
	puts(g, [Vector2i(23, 19), Vector2i(11, 22), Vector2i(50, 26)], "o")
	puts(g, [Vector2i(26, 19), Vector2i(14, 22), Vector2i(22, 26), Vector2i(44, 26)], "S")
	put(g, 3, 26, "P")
	put(g, 55, 26, "X")
	return bake(g)


## Springs. The exit sits two spring-heights above the floor.
##
## Every platform a spring fires into has to be one-way, or the launch just
## slams into its underside — a spring under solid ground goes nowhere.
static func _level_5() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 22, 8, 15, 1, "-")      # spring at col 28 passes up through this
	rect(g, 4, 16, 13, 1, "-")      # spring at col 8 passes up through this
	rect(g, 44, 16, 13, 1, "-")     # spring at col 50 passes up through this
	rect(g, 20, 20, 13, 1, "#")
	puts(g, [Vector2i(8, 26), Vector2i(50, 26), Vector2i(28, 19)], "J")
	puts(g, [Vector2i(26, 7), Vector2i(8, 15), Vector2i(50, 15), Vector2i(22, 19)], "o")
	put(g, 3, 26, "P")
	put(g, 32, 7, "X")
	return bake(g)


## A wall-jump shaft, with an optional spike run along the floor.
static func _level_6() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 17, 7, 1, 18, "#")      # right wall of the shaft
	rect(g, 12, 9, 1, 16, "#")      # left wall, stops short so you can exit
	rect(g, 4, 8, 9, 1, "#")        # landing at the top of the climb
	rect(g, 17, 6, 12, 1, "#")
	rect(g, 34, 6, 13, 1, "#")
	rect(g, 30, 26, 5, 1, "^")
	rect(g, 44, 26, 3, 1, "^")
	puts(g, [Vector2i(14, 13), Vector2i(15, 19), Vector2i(22, 5), Vector2i(52, 26)], "o")
	put(g, 24, 26, "S")
	put(g, 3, 26, "P")
	put(g, 40, 5, "X")
	return bake(g)


## Two routes over three spiked pits: the floor, with slimes patrolling between
## the pits, or a chain of one-way ledges overhead carrying the gems.
static func _level_7() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	# Pits are five tiles wide: 40px, well inside a 61px jump.
	for pit: Vector2i in [Vector2i(14, 5), Vector2i(28, 5), Vector2i(44, 5)]:
		rect(g, pit.x, 27, pit.y, 3, ".")
		rect(g, pit.x, 30, pit.y, 1, "^")
	# Ledges sit four tiles up with five-tile gaps between them.
	rect(g, 8, 23, 6, 1, "-")
	rect(g, 19, 23, 6, 1, "-")
	rect(g, 30, 23, 6, 1, "-")
	puts(g, [Vector2i(10, 22), Vector2i(21, 22), Vector2i(32, 22), Vector2i(52, 26)], "o")
	puts(g, [Vector2i(10, 26), Vector2i(24, 26), Vector2i(38, 26)], "S")
	put(g, 3, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## A spring staircase. Each spring stands on the tier below it and fires
## through the one-way tier above — a spring under solid ground is a dead end.
static func _level_8() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 4, 16, 17, 1, "-")      # tier one, reached from the floor spring
	rect(g, 14, 6, 21, 1, "-")      # tier two, reached from the tier-one spring
	rect(g, 42, 16, 14, 1, "-")     # optional side tier for one more gem
	puts(g, [Vector2i(8, 26), Vector2i(18, 15), Vector2i(48, 26)], "J")
	puts(g, [Vector2i(6, 15), Vector2i(24, 5), Vector2i(32, 5), Vector2i(50, 15)], "o")
	put(g, 3, 26, "P")
	put(g, 30, 5, "X")
	return bake(g)


## A staircase of one-way ledges, three tiles up and four across each time,
## with a slime waiting on every step.
static func _level_9() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 10, 24, 7, 1, "-")
	rect(g, 21, 21, 7, 1, "-")
	rect(g, 32, 18, 7, 1, "-")
	rect(g, 43, 15, 7, 1, "-")
	rect(g, 52, 12, 7, 1, "-")
	puts(g, [Vector2i(14, 23), Vector2i(25, 20), Vector2i(36, 17), Vector2i(47, 14)], "S")
	puts(g, [Vector2i(11, 23), Vector2i(22, 20), Vector2i(33, 17), Vector2i(44, 14), Vector2i(57, 11)], "o")
	put(g, 3, 26, "P")
	put(g, 54, 11, "X")
	return bake(g)


## Spikes strung along the floor, with a high ledge route above them.
static func _level_10() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 6, 20, 6, 1, "#")
	rect(g, 14, 23, 8, 1, "#")
	rect(g, 24, 20, 6, 1, "#")
	rect(g, 32, 23, 8, 1, "#")
	rect(g, 42, 20, 6, 1, "#")
	rect(g, 50, 23, 10, 1, "#")
	puts(g, [Vector2i(8, 26), Vector2i(18, 26), Vector2i(28, 26),
		Vector2i(38, 26), Vector2i(48, 26)], "^")
	puts(g, [Vector2i(10, 19), Vector2i(26, 19), Vector2i(44, 19),
		Vector2i(20, 22), Vector2i(40, 22)], "o")
	put(g, 3, 26, "P")
	put(g, 55, 22, "X")
	return bake(g)


## Two spring launches straight up a tower. Everything above a spring is
## one-way, so each launch passes through and lands on top.
static func _level_11() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 14, 26, 3, 1, "^")
	rect(g, 22, 18, 13, 1, "-")     # first landing, 9 tiles up
	rect(g, 20, 8, 13, 1, "-")      # second landing, 10 tiles above that
	puts(g, [Vector2i(28, 26), Vector2i(26, 17)], "J")
	puts(g, [Vector2i(24, 17), Vector2i(32, 17), Vector2i(22, 7),
		Vector2i(31, 7), Vector2i(8, 26)], "o")
	put(g, 3, 26, "P")
	put(g, 26, 7, "X")
	return bake(g)


## The finale. Spikes and a slime on the floor, a wall-jump shaft that is the
## only way up, then a gap to the last tier. The spring is an optional detour.
static func _level_12() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 8, 26, 2, 1, "^")
	rect(g, 20, 8, 1, 17, "#")      # shaft, left wall
	rect(g, 25, 8, 1, 17, "#")      # shaft, right wall
	rect(g, 25, 7, 12, 1, "#")      # landing on top of the right wall
	rect(g, 42, 7, 11, 1, "#")      # last tier, five tiles across the gap
	rect(g, 36, 14, 11, 1, "-")     # optional gem tier under the spring
	puts(g, [Vector2i(14, 26), Vector2i(45, 6)], "S")
	put(g, 40, 26, "J")
	puts(g, [Vector2i(22, 15), Vector2i(28, 6), Vector2i(34, 6),
		Vector2i(40, 13), Vector2i(50, 6)], "o")
	put(g, 3, 26, "P")
	put(g, 48, 6, "X")
	return bake(g)


## Dash school. The gaps are nine tiles across — a jump covers seven and a
## half, so the only way over is jump then dash.
static func _level_13() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	for pit: Vector2i in [Vector2i(13, 9), Vector2i(27, 9), Vector2i(41, 9)]:
		rect(g, pit.x, 27, pit.y, 3, ".")
		rect(g, pit.x, 30, pit.y, 1, "^")
	puts(g, [Vector2i(17, 24), Vector2i(31, 24), Vector2i(45, 24)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## An inverted stair of crystals over one long pit. Each crystal hands the
## dash back, so the route stays airborne from start to finish.
static func _level_14() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 10, 27, 40, 3, ".")
	rect(g, 10, 30, 40, 1, "^")
	puts(g, [Vector2i(14, 23), Vector2i(20, 23), Vector2i(26, 24),
		Vector2i(32, 24), Vector2i(38, 25), Vector2i(44, 25)], "d")
	puts(g, [Vector2i(19, 20), Vector2i(31, 20), Vector2i(43, 20)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Ferries. Two slabs slide sideways and one rides up and down; each works out
## its own run from the empty space around it.
static func _level_15() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 10, 27, 42, 3, ".")
	rect(g, 10, 30, 42, 1, "^")
	rect(g, 14, 23, 3, 1, "m")
	rect(g, 28, 20, 3, 1, "n")
	rect(g, 42, 23, 3, 1, "m")
	puts(g, [Vector2i(21, 21), Vector2i(34, 17), Vector2i(48, 21)], "o")
	put(g, 4, 26, "P")
	put(g, 55, 26, "X")
	return bake(g)


## Rhythm. Neighbouring pairs run opposite phases, so there is always a next
## block coming — the room asks you to wait, which no other room does.
static func _level_16() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 10, 27, 40, 3, ".")
	rect(g, 10, 30, 40, 1, "^")
	var x := 12
	var flip := false
	while x < 48:
		rect(g, x, 25, 2, 1, "T" if flip else "t")
		flip = not flip
		x += 4
	puts(g, [Vector2i(20, 22), Vector2i(32, 22), Vector2i(44, 22)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Spike runs eight tiles long: too far to jump, exactly right to dash, with a
## crystal parked before each one.
static func _level_17() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	for run: int in [14, 28, 42]:
		rect(g, run, 26, 8, 1, "^")
	puts(g, [Vector2i(12, 24), Vector2i(26, 24), Vector2i(40, 24)], "d")
	puts(g, [Vector2i(18, 22), Vector2i(32, 22), Vector2i(46, 22)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## The finale of the new stretch: a ferry, a beat, a crystal, a lift, and
## something in the air over all of it.
static func _level_18() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 9, 27, 43, 3, ".")
	rect(g, 9, 30, 43, 1, "^")
	rect(g, 12, 24, 3, 1, "m")
	rect(g, 22, 22, 2, 1, "t")
	rect(g, 26, 22, 2, 1, "T")
	rect(g, 30, 22, 2, 1, "t")
	put(g, 35, 20, "d")
	rect(g, 39, 20, 3, 1, "n")
	rect(g, 46, 23, 5, 1, "-")
	put(g, 44, 17, "B")
	puts(g, [Vector2i(17, 21), Vector2i(27, 19), Vector2i(48, 21)], "o")
	put(g, 4, 26, "P")
	put(g, 55, 26, "X")
	return bake(g)


## Pound school. Three pockets sealed under breakable lids, each with a gem
## in it. Nothing here can kill you — the room only asks you to find the verb.
static func _level_19() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	for lid: int in [14, 28, 42]:
		rect(g, lid, 27, 3, 1, "k")
		rect(g, lid, 28, 3, 2, ".")
		put(g, lid + 1, 29, "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## The whole middle of the floor is breakable, and the room under it is where
## the gems live. Break in wherever you like; the way back out is the hole you
## made.
static func _level_20() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 12, 27, 35, 1, "k")
	rect(g, 12, 28, 32, 3, ".")
	rect(g, 20, 30, 5, 1, "^")
	rect(g, 34, 30, 5, 1, "^")
	puts(g, [Vector2i(16, 29), Vector2i(30, 29), Vector2i(42, 29)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Bouncing across. Every slime taken without touching the ground throws you
## higher than the last, so the crossing gets easier the better you read it.
static func _level_21() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 10, 27, 40, 3, ".")
	rect(g, 10, 30, 40, 1, "^")
	var x := 14
	while x < 48:
		rect(g, x, 24, 2, 1, "-")
		put(g, x, 23, "S")
		x += 6
	puts(g, [Vector2i(21, 20), Vector2i(33, 20), Vector2i(45, 20)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Slippery ground from start to finish. No obstacles, only inertia.
static func _level_ice_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 10, 27, 40, 1, "~")          # ice surface, only top line
	puts(g, [Vector2i(18, 26), Vector2i(30, 26), Vector2i(42, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Ice plates separated by pits with spikes at the bottom.
static func _level_ice_edge() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	# Ice plates of 8 tiles, separated by 4-tile pits with spikes
	for x in [10, 28, 46]:
		rect(g, x, 27, 8, 1, "~")
		if x + 8 < COLS:
			rect(g, x + 8, 29, 4, 1, "^")
	puts(g, [Vector2i(14, 26), Vector2i(32, 26), Vector2i(50, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Ice corridor ending in a tall wall — the wall is your brake.
static func _level_ice_wall() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 6, 15, 48, 1, "#")          # wall in the middle
	rect(g, 8, 27, 44, 1, "~")          # ice below
	puts(g, [Vector2i(24, 26), Vector2i(36, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 48, 14, "X")
	return bake(g)


## Ice with walking slimes — the slimes move on ice too.
static func _level_ice_slime() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 10, 27, 40, 1, "~")
	rect(g, 24, 25, 12, 1, "-")         # escape platform
	puts(g, [Vector2i(18, 26), Vector2i(40, 26)], "o")
	puts(g, [Vector2i(14, 26), Vector2i(26, 26), Vector2i(44, 26)], "S")
	put(g, 4, 26, "P")
	put(g, 54, 24, "X")
	return bake(g)


## "name" and "hint" are translation keys, not text — every screen that shows
## them runs them through Lang.t() so a language switch needs no rebuild here.
static func all() -> Array:
	return [
		{
			"id": "first_steps",
			"name": "level.1.name",
			"hint": "level.1.hint",
			"par": 20.0,
			"rows": _level_1(),
		},
		{
			"id": "prickly",
			"name": "level.2.name",
			"hint": "level.2.hint",
			"par": 28.0,
			"rows": _level_2(),
		},
		{
			"id": "ceiling_spikes",
			"name": "level.3.name",
			"hint": "level.3.hint",
			"par": 32.0,
			"rows": _level_3(),
		},
		{
			"id": "slime_time",
			"name": "level.4.name",
			"hint": "level.4.hint",
			"par": 38.0,
			"rows": _level_4(),
		},
		{
			"id": "bounce",
			"name": "level.5.name",
			"hint": "level.5.hint",
			"par": 42.0,
			"rows": _level_5(),
		},
		{
			"id": "the_climb",
			"name": "level.6.name",
			"hint": "level.6.hint",
			"par": 60.0,
			"rows": _level_6(),
		},
		{
			"id": "double_trouble",
			"name": "level.7.name",
			"hint": "level.7.hint",
			"par": 45.0,
			"rows": _level_7(),
		},
		{
			"id": "spring_stair",
			"name": "level.8.name",
			"hint": "level.8.hint",
			"par": 50.0,
			"rows": _level_8(),
		},
		{
			"id": "ledge_climb",
			"name": "level.9.name",
			"hint": "level.9.hint",
			"par": 55.0,
			"rows": _level_9(),
		},
		{
			"id": "spike_gauntlet",
			"name": "level.10.name",
			"hint": "level.10.hint",
			"par": 48.0,
			"rows": _level_10(),
		},
		{
			"id": "spring_tower",
			"name": "level.11.name",
			"hint": "level.11.hint",
			"par": 52.0,
			"rows": _level_11(),
		},
		{
			"id": "wall_finale",
			"name": "level.12.name",
			"hint": "level.12.hint",
			"par": 90.0,
			"rows": _level_12(),
		},
		{
			"id": "first_dash",
			"name": "level.13.name",
			"hint": "level.13.hint",
			"par": 30.0,
			"rows": _level_13(),
		},
		{
			"id": "crystal_chain",
			"name": "level.14.name",
			"hint": "level.14.hint",
			"par": 40.0,
			"rows": _level_14(),
		},
		{
			"id": "platform_ride",
			"name": "level.15.name",
			"hint": "level.15.hint",
			"par": 45.0,
			"rows": _level_15(),
		},
		{
			"id": "beat",
			"name": "level.16.name",
			"hint": "level.16.hint",
			"par": 50.0,
			"rows": _level_16(),
		},
		{
			"id": "dash_gauntlet",
			"name": "level.17.name",
			"hint": "level.17.hint",
			"par": 42.0,
			"rows": _level_17(),
		},
		{
			"id": "mid_finale",
			"name": "level.18.name",
			"hint": "level.18.hint",
			"par": 75.0,
			"rows": _level_18(),
		},
		{
			"id": "slam",
			"name": "level.19.name",
			"hint": "level.19.hint",
			"par": 35.0,
			"rows": _level_19(),
		},
		{
			"id": "break_in",
			"name": "level.20.name",
			"hint": "level.20.hint",
			"par": 55.0,
			"rows": _level_20(),
		},
		{
			"id": "chain_bounce",
			"name": "level.21.name",
			"hint": "level.21.hint",
			"par": 60.0,
			"rows": _level_21(),
		},
		{
			"id": "ice_first",
			"name": "level.ice_first.name",
			"hint": "level.ice_first.hint",
			"par": 22.0,
			"rows": _level_ice_first(),
		},
		{
			"id": "ice_edge",
			"name": "level.ice_edge.name",
			"hint": "level.ice_edge.hint",
			"par": 30.0,
			"rows": _level_ice_edge(),
		},
		{
			"id": "ice_wall",
			"name": "level.ice_wall.name",
			"hint": "level.ice_wall.hint",
			"par": 34.0,
			"rows": _level_ice_wall(),
		},
		{
			"id": "ice_slime",
			"name": "level.ice_slime.name",
			"hint": "level.ice_slime.hint",
			"par": 40.0,
			"rows": _level_ice_slime(),
		},
	]


static func count() -> int:
	return all().size()


static func index_of(room_id: String) -> int:
	for i in all().size():
		if all()[i].get("id", "") == room_id:
			return i
	return -1
