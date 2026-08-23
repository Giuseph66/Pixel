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

const COLS := 60
const ROWS := 32


# --------------------------------------------------------------- painting ---

static func _blank() -> Array:
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


static func _rect(grid: Array, x: int, y: int, w: int, h: int, ch: String) -> void:
	for j in range(y, y + h):
		if j < 0 or j >= ROWS:
			continue
		for i in range(x, x + w):
			if i < 0 or i >= COLS:
				continue
			grid[j][i] = ch


static func _put(grid: Array, x: int, y: int, ch: String) -> void:
	if x < 0 or y < 0 or x >= COLS or y >= ROWS:
		return
	grid[y][x] = ch


static func _puts(grid: Array, points: Array, ch: String) -> void:
	for p: Vector2i in points:
		_put(grid, p.x, p.y, ch)


static func _bake(grid: Array) -> PackedStringArray:
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
	var g := _blank()
	_rect(g, 0, 27, COLS, 5, "#")
	_rect(g, 16, 25, 7, 2, "#")
	_rect(g, 27, 22, 8, 5, "#")
	_rect(g, 38, 19, 15, 8, "#")
	_puts(g, [Vector2i(19, 24), Vector2i(30, 21), Vector2i(44, 18)], "o")
	_put(g, 4, 26, "P")
	_put(g, 48, 18, "X")
	return _bake(g)


## Spiked pits, one-way platforms overhead.
static func _level_2() -> PackedStringArray:
	var g := _blank()
	_rect(g, 0, 27, COLS, 5, "#")
	# Each pit is (start column, width): three tiles of air over a bed of spikes.
	for pit: Vector2i in [Vector2i(13, 5), Vector2i(27, 6), Vector2i(43, 5)]:
		var start := pit.x
		var width := pit.y
		_rect(g, start, 27, width, 3, ".")
		_rect(g, start, 30, width, 1, "^")
	_rect(g, 10, 23, 5, 1, "-")
	_rect(g, 35, 23, 6, 1, "-")
	_rect(g, 17, 20, 6, 1, "#")
	_rect(g, 50, 24, 10, 3, "#")
	_puts(g, [Vector2i(12, 22), Vector2i(19, 19), Vector2i(37, 22)], "o")
	_put(g, 4, 26, "P")
	_put(g, 53, 23, "X")
	return _bake(g)


## Low ceiling with hanging spikes, spike patches on the floor.
static func _level_3() -> PackedStringArray:
	var g := _blank()
	_rect(g, 0, 27, COLS, 5, "#")
	_rect(g, 6, 18, 39, 3, "#")
	# Hung where nobody needs to jump: they punish reflex jumping, not routing.
	_puts(g, [Vector2i(24, 21), Vector2i(25, 21), Vector2i(28, 21), Vector2i(29, 21)], "v")
	_rect(g, 12, 26, 3, 1, "^")
	_rect(g, 20, 26, 3, 1, "^")
	_rect(g, 34, 26, 3, 1, "^")
	_rect(g, 46, 23, 14, 4, "#")
	_puts(g, [Vector2i(13, 25), Vector2i(21, 25), Vector2i(35, 25)], "o")
	_put(g, 3, 26, "P")
	_put(g, 49, 22, "X")
	return _bake(g)


## Patrolling slimes on the ground and on two floating platforms.
static func _level_4() -> PackedStringArray:
	var g := _blank()
	_rect(g, 0, 27, COLS, 5, "#")
	_rect(g, 22, 20, 9, 1, "#")
	_rect(g, 10, 23, 9, 1, "#")
	_puts(g, [Vector2i(23, 19), Vector2i(11, 22), Vector2i(50, 26)], "o")
	_puts(g, [Vector2i(26, 19), Vector2i(14, 22), Vector2i(22, 26), Vector2i(44, 26)], "S")
	_put(g, 3, 26, "P")
	_put(g, 55, 26, "X")
	return _bake(g)


## Springs. The exit sits two spring-heights above the floor.
##
## Every platform a spring fires into has to be one-way, or the launch just
## slams into its underside — a spring under solid ground goes nowhere.
static func _level_5() -> PackedStringArray:
	var g := _blank()
	_rect(g, 0, 27, COLS, 5, "#")
	_rect(g, 22, 8, 15, 1, "-")      # spring at col 28 passes up through this
	_rect(g, 4, 16, 13, 1, "-")      # spring at col 8 passes up through this
	_rect(g, 44, 16, 13, 1, "-")     # spring at col 50 passes up through this
	_rect(g, 20, 20, 13, 1, "#")
	_puts(g, [Vector2i(8, 26), Vector2i(50, 26), Vector2i(28, 19)], "J")
	_puts(g, [Vector2i(26, 7), Vector2i(8, 15), Vector2i(50, 15), Vector2i(22, 19)], "o")
	_put(g, 3, 26, "P")
	_put(g, 32, 7, "X")
	return _bake(g)


## A wall-jump shaft, with an optional spike run along the floor.
static func _level_6() -> PackedStringArray:
	var g := _blank()
	_rect(g, 0, 27, COLS, 5, "#")
	_rect(g, 17, 7, 1, 18, "#")      # right wall of the shaft
	_rect(g, 12, 9, 1, 16, "#")      # left wall, stops short so you can exit
	_rect(g, 4, 8, 9, 1, "#")        # landing at the top of the climb
	_rect(g, 17, 6, 12, 1, "#")
	_rect(g, 34, 6, 13, 1, "#")
	_rect(g, 30, 26, 5, 1, "^")
	_rect(g, 44, 26, 3, 1, "^")
	_puts(g, [Vector2i(14, 13), Vector2i(15, 19), Vector2i(22, 5), Vector2i(52, 26)], "o")
	_put(g, 24, 26, "S")
	_put(g, 3, 26, "P")
	_put(g, 40, 5, "X")
	return _bake(g)


## Slimes in pits: stomp them or jump over. If you miss, spikes catch you.
static func _level_7() -> PackedStringArray:
	var g := _blank()
	_rect(g, 0, 27, COLS, 5, "#")
	_rect(g, 8, 21, 11, 1, "#")
	_rect(g, 24, 21, 12, 1, "#")
	_rect(g, 42, 21, 14, 1, "#")
	# Three pits with slimes; spike bed below each.
	for pit: Vector2i in [Vector2i(12, 8), Vector2i(28, 8), Vector2i(46, 8)]:
		_rect(g, pit.x, pit.y, pit.y, 5, ".")
		_rect(g, pit.x, pit.y + 5, pit.y, 1, "^")
	_puts(g, [Vector2i(14, 21), Vector2i(30, 21), Vector2i(48, 21)], "S")
	_puts(g, [Vector2i(16, 20), Vector2i(32, 20), Vector2i(50, 20), Vector2i(26, 15)], "o")
	_put(g, 3, 26, "P")
	_put(g, 55, 26, "X")
	return _bake(g)


## Springs under platforms: launch from below to access higher ledges.
static func _level_8() -> PackedStringArray:
	var g := _blank()
	_rect(g, 0, 27, COLS, 5, "#")
	_rect(g, 8, 14, 16, 1, "-")
	_rect(g, 30, 10, 18, 1, "-")
	_rect(g, 52, 6, 8, 1, "#")
	_rect(g, 6, 22, 3, 1, "#")
	_rect(g, 28, 22, 3, 1, "#")
	_rect(g, 50, 22, 3, 1, "#")
	_puts(g, [Vector2i(7, 23), Vector2i(29, 23), Vector2i(51, 23)], "J")
	_puts(g, [Vector2i(10, 13), Vector2i(18, 13), Vector2i(32, 9), Vector2i(40, 9), Vector2i(54, 5)], "o")
	_put(g, 3, 26, "P")
	_put(g, 56, 5, "X")
	return _bake(g)


## Narrow corridors with slimes. Dodge or stomp, then navigate tight spaces.
static func _level_9() -> PackedStringArray:
	var g := _blank()
	_rect(g, 0, 27, COLS, 5, "#")
	_rect(g, 10, 22, 7, 1, "#")
	_rect(g, 20, 18, 7, 1, "#")
	_rect(g, 30, 14, 7, 1, "#")
	_rect(g, 40, 10, 7, 1, "#")
	_rect(g, 50, 6, 10, 1, "#")
	# Slimes block the path; you must jump over or defeat them.
	_puts(g, [Vector2i(13, 21), Vector2i(23, 17), Vector2i(33, 13), Vector2i(43, 9)], "S")
	_puts(g, [Vector2i(11, 20), Vector2i(21, 16), Vector2i(31, 12), Vector2i(41, 8), Vector2i(52, 4)], "o")
	_put(g, 3, 26, "P")
	_put(g, 55, 5, "X")
	return _bake(g)


## Maze-like with spikes. Find the safe path through a complex layout.
static func _level_10() -> PackedStringArray:
	var g := _blank()
	_rect(g, 0, 27, COLS, 5, "#")
	_rect(g, 6, 20, 6, 1, "#")
	_rect(g, 14, 23, 8, 1, "#")
	_rect(g, 24, 20, 6, 1, "#")
	_rect(g, 32, 23, 8, 1, "#")
	_rect(g, 42, 20, 6, 1, "#")
	_rect(g, 50, 23, 10, 1, "#")
	# Spike traps in the gaps.
	_puts(g, [Vector2i(8, 26), Vector2i(18, 26), Vector2i(28, 26), Vector2i(38, 26), Vector2i(48, 26)], "^")
	_puts(g, [Vector2i(10, 19), Vector2i(26, 19), Vector2i(44, 19), Vector2i(20, 22), Vector2i(40, 22)], "o")
	_put(g, 3, 26, "P")
	_put(g, 55, 22, "X")
	return _bake(g)


## Spring tower: use springs to climb a tall shaft.
static func _level_11() -> PackedStringArray:
	var g := _blank()
	_rect(g, 0, 27, COLS, 5, "#")
	_rect(g, 22, 22, 2, 1, "#")
	_rect(g, 21, 16, 2, 1, "#")
	_rect(g, 22, 10, 2, 1, "#")
	_rect(g, 21, 4, 2, 1, "#")
	# Springs on both sides to bounce up the shaft.
	_puts(g, [Vector2i(19, 23), Vector2i(25, 23), Vector2i(18, 17), Vector2i(26, 17)], "J")
	_puts(g, [Vector2i(18, 11), Vector2i(26, 11), Vector2i(19, 5), Vector2i(25, 5)], "J")
	_puts(g, [Vector2i(22, 20), Vector2i(21, 14), Vector2i(22, 8), Vector2i(21, 2)], "o")
	_put(g, 3, 26, "P")
	_put(g, 22, 1, "X")
	return _bake(g)


## Final gauntlet: slimes, spikes, springs, walls, pits. Everything at once.
static func _level_12() -> PackedStringArray:
	var g := _blank()
	_rect(g, 0, 27, COLS, 5, "#")
	_rect(g, 6, 22, 8, 1, "#")
	_rect(g, 18, 19, 8, 1, "-")
	_rect(g, 30, 16, 8, 1, "#")
	_rect(g, 42, 13, 8, 1, "-")
	_rect(g, 20, 8, 1, 8, "#")      # wall to jump on
	_puts(g, [Vector2i(8, 23), Vector2i(32, 23), Vector2i(50, 23)], "^")
	_puts(g, [Vector2i(10, 21), Vector2i(34, 15), Vector2i(54, 12)], "S")
	_puts(g, [Vector2i(22, 23), Vector2i(35, 23), Vector2i(46, 12)], "J")
	_puts(g, [Vector2i(12, 20), Vector2i(24, 18), Vector2i(36, 14), Vector2i(48, 10), Vector2i(56, 6)], "o")
	_put(g, 3, 26, "P")
	_put(g, 56, 5, "X")
	return _bake(g)


## "name" and "hint" are translation keys, not text — every screen that shows
## them runs them through Lang.t() so a language switch needs no rebuild here.
static func all() -> Array:
	return [
		{
			"name": "level.1.name",
			"hint": "level.1.hint",
			"par": 20.0,
			"rows": _level_1(),
		},
		{
			"name": "level.2.name",
			"hint": "level.2.hint",
			"par": 28.0,
			"rows": _level_2(),
		},
		{
			"name": "level.3.name",
			"hint": "level.3.hint",
			"par": 32.0,
			"rows": _level_3(),
		},
		{
			"name": "level.4.name",
			"hint": "level.4.hint",
			"par": 38.0,
			"rows": _level_4(),
		},
		{
			"name": "level.5.name",
			"hint": "level.5.hint",
			"par": 42.0,
			"rows": _level_5(),
		},
		{
			"name": "level.6.name",
			"hint": "level.6.hint",
			"par": 60.0,
			"rows": _level_6(),
		},
		{
			"name": "level.7.name",
			"hint": "level.7.hint",
			"par": 45.0,
			"rows": _level_7(),
		},
		{
			"name": "level.8.name",
			"hint": "level.8.hint",
			"par": 50.0,
			"rows": _level_8(),
		},
		{
			"name": "level.9.name",
			"hint": "level.9.hint",
			"par": 55.0,
			"rows": _level_9(),
		},
		{
			"name": "level.10.name",
			"hint": "level.10.hint",
			"par": 48.0,
			"rows": _level_10(),
		},
		{
			"name": "level.11.name",
			"hint": "level.11.hint",
			"par": 52.0,
			"rows": _level_11(),
		},
		{
			"name": "level.12.name",
			"hint": "level.12.hint",
			"par": 90.0,
			"rows": _level_12(),
		},
	]


static func count() -> int:
	return all().size()
