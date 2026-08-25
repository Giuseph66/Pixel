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
##   ~  ice, almost no friction  r  slab that rides a circle
##   >  belt, pushes right       e  elastic slime, bounces you and lives
##   <  belt, pushes left        E  shielded walker, only a pound gets through
##   z  timed spike, down first  A  the line a rising tide starts from
##   Z  timed spike, up first    O  secret gem, outside the door's count

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


## A long sheet with pillars planted in it. Running into one costs nothing but
## the hop over it, and that crash is the first time the ice says what it is.
## Getting the gem on top is the second time: the pillar top is ordinary stone,
## so you stop dead up there and start sliding again the moment you step off.
static func _level_ice_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 8, 27, 44, 1, "~")
	for x in [20, 32, 44]:
		rect(g, x, 23, 2, 4, "#")
	puts(g, [Vector2i(20, 22), Vector2i(32, 22), Vector2i(44, 22)], "o")
	put(g, 54, 20, "O")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Ice plates separated by pits with spikes at the bottom.
static func _level_ice_edge() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	# Plates of ice with real gaps between them. Four tiles is inside a running
	# jump; what makes it hard is arriving at the edge still carrying speed.
	for x in [10, 24, 38]:
		rect(g, x, 27, 10, 1, "~")
		rect(g, x + 10, 27, 4, 3, ".")
		rect(g, x + 10, 30, 4, 1, "^")
	# The last plate has a blade on it. Its pen is the plate: the saw turns at
	# both edges, so the question is arriving on ice you cannot brake on with
	# somewhere left to stand.
	put(g, 45, 26, "W")
	puts(g, [Vector2i(14, 26), Vector2i(28, 26), Vector2i(42, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Ice parkour crosses a spike trench, climbs the ice wall at the right, then
## returns through the high platforms to the upper-left exit.
static func _level_ice_wall() -> PackedStringArray:
	var g := blank()
	# Platforms are ice; the right climb wall stays normal.
	rect(g, 0, 27, 4, 5, "~")
	rect(g, 54, 27, 6, 5, "~")
	rect(g, 4, 30, 20, 1, "^")
	rect(g, 26, 30, 28, 1, "^")

	# Low route to the ice wall on the right.
	rect(g, 10, 25, 2, 1, "~")
	rect(g, 17, 23, 2, 1, "~")
	rect(g, 23, 21, 2, 1, "~")
	rect(g, 28, 19, 2, 1, "~")
	rect(g, 38, 22, 2, 1, "~")
	rect(g, 44, 20, 2, 1, "~")
	rect(g, 48, 24, 2, 1, "~")
	rect(g, 52, 23, 2, 1, "~")
	rect(g, 58, 9, 2, 7, "#")

	# Return path after the wall, ending at the high-left portal.
	rect(g, 49, 10, 2, 1, "~")
	rect(g, 41, 10, 2, 1, "~")
	rect(g, 33, 9, 2, 1, "~")
	rect(g, 25, 9, 2, 1, "~")
	rect(g, 17, 10, 2, 1, "~")
	rect(g, 9, 10, 2, 1, "~")
	rect(g, 2, 5, 6, 1, "~")
	puts(g, [Vector2i(10, 9), Vector2i(26, 8), Vector2i(49, 23)], "o")
	put(g, 2, 26, "P")
	put(g, 3, 4, "X")
	return bake(g)


## Three ice plates, with a slime before every commitment. Stomping clears one
## threat, but the remaining momentum still has to clear the next spike pit.
static func _level_ice_slime() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	for plate in [Vector2i(8, 10), Vector2i(24, 10), Vector2i(40, 12)]:
		rect(g, plate.x, 27, plate.y, 1, "~")
	for pit in [Vector2i(18, 6), Vector2i(34, 6)]:
		rect(g, pit.x, 27, pit.y, 3, ".")
		rect(g, pit.x, 30, pit.y, 1, "^")
	puts(g, [Vector2i(12, 26), Vector2i(28, 26), Vector2i(48, 26)], "o")
	puts(g, [Vector2i(15, 26), Vector2i(31, 26), Vector2i(45, 26)], "S")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## The player is standing on the belt before they have touched a key. The floor
## carries them, and the lesson lands in two seconds without a word of hint.
## Short belts with long stretches of ordinary floor between them was the
## earlier shape of this room, and it read as nothing happening at all.
static func _level_belt_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 3, 27, 22, 1, ">")
	rect(g, 30, 27, 22, 1, ">")
	puts(g, [Vector2i(12, 26), Vector2i(27, 26), Vector2i(44, 26)], "o")
	put(g, 8, 20, "O")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Walking against the belt: the belt pushes left, the goal is right.
static func _level_belt_against() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 10, 27, 40, 1, "<")
	# A blade on the belt. Jumping over it also costs you the push, which is
	# the trade the whole room is about.
	put(g, 40, 26, "W")
	puts(g, [Vector2i(30, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Belt launch: moving ground accelerates the jump across a pit.
static func _level_belt_launch() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 12, 27, 10, 1, ">")
	rect(g, 24, 27, 6, 3, ".")           # the pit
	rect(g, 24, 30, 6, 1, "^")
	rect(g, 34, 27, 8, 1, ">")
	# A bat over the pit, exactly where the belt throws you. Stomp it and the
	# bounce finishes the crossing; miss and the belt has already committed you.
	put(g, 26, 23, "B")
	puts(g, [Vector2i(20, 24), Vector2i(40, 26)], "o")
	put(g, 8, 20, "O")
	put(g, 4, 26, "P")
	put(g, 52, 26, "X")
	return bake(g)


## Belts against belts. Each stretch is eight tiles, which is long enough to
## commit to before the next one argues with you; the four-tile version of this
## room cancelled itself out before the player could feel either direction.
static func _level_belt_mix() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	var pushing_right := true
	for x in [6, 14, 22, 30, 38, 46]:
		rect(g, x, 27, 8, 1, ">" if pushing_right else "<")
		pushing_right = not pushing_right
	puts(g, [Vector2i(18, 26), Vector2i(34, 26), Vector2i(50, 26)], "o")
	puts(g, [Vector2i(12, 26), Vector2i(28, 26)], "S")
	put(g, 4, 26, "P")
	put(g, 56, 26, "X")
	return bake(g)


## Pulsing spikes: three groups with safe ground between them.
static func _level_retract_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	for x in [14, 26, 38]:
		rect(g, x, 26, 3, 1, "z")
	puts(g, [Vector2i(20, 25), Vector2i(32, 25), Vector2i(44, 25)], "o")
	put(g, 50, 20, "O")
	put(g, 4, 26, "P")
	put(g, 52, 26, "X")
	return bake(g)


## Running through alternating spikes: one line up and down.
static func _level_retract_run() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	for x in range(12, 48, 3):
		if (x / 3) % 2 == 0:
			put(g, x, 26, "z")
		else:
			put(g, x, 26, "Z")
	puts(g, [Vector2i(24, 25), Vector2i(36, 25)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Timed block and spike: they dance together. The door sits on a shelf that
## only the blocks reach, and 't' is solid exactly while 'T' is not — so the
## climb is one jump per beat, taken on the blink. Miss it and you land in the
## spike field, which keeps its own clock. Reading both is the whole room.
static func _level_retract_drop() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	# The climb. Every step hands you to the next one as it goes.
	rect(g, 18, 24, 2, 1, "t")
	rect(g, 24, 22, 2, 1, "T")
	rect(g, 30, 20, 2, 1, "t")
	rect(g, 36, 20, 2, 1, "T")
	# The shelf, solid: once you are up, you are up.
	rect(g, 42, 20, 8, 1, "#")
	# What a missed beat costs. Kept out of the block columns, so a risen blade
	# never grows into the platform someone is about to land on.
	for x in [21, 27, 33, 39]:
		put(g, x, 26, "z")
	puts(g, [Vector2i(24, 21), Vector2i(36, 19)], "o")
	put(g, 4, 26, "P")
	put(g, 48, 19, "X")
	return bake(g)


## Spike and saw: two timers on the same screen.
static func _level_retract_saw() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 10, 24, 40, 1, "#")
	for x in [16, 22, 28, 34, 40, 46]:
		put(g, x, 26, "z")
	put(g, 32, 23, "W")
	puts(g, [Vector2i(24, 25), Vector2i(40, 25)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## The orbit ferries you across. Board it on the left bank, step off on the
## right; the circle always comes back, so a missed jump costs a lap, not a life.
static func _level_orbit_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 24, 27, 12, 3, ".")
	rect(g, 24, 30, 12, 1, "^")
	rect(g, 29, 25, 2, 1, "r")
	puts(g, [Vector2i(21, 25), Vector2i(29, 20), Vector2i(40, 25)], "o")
	put(g, 8, 20, "O")
	put(g, 4, 26, "P")
	put(g, 52, 26, "X")
	return bake(g)


## Two circles, out of phase, with a ledge between them. Every gem sits at the
## top of a lap, so the room asks which lap to take rather than which jump.
static func _level_orbit_gems() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 14, 27, 32, 3, ".")
	rect(g, 14, 30, 32, 1, "^")
	rect(g, 28, 24, 4, 1, "#")
	rect(g, 20, 25, 2, 1, "r")
	rect(g, 38, 25, 2, 1, "r")
	# It patrols the island between the two orbits — the one place you were
	# counting on standing still.
	put(g, 29, 21, "B")
	puts(g, [Vector2i(20, 20), Vector2i(29, 22), Vector2i(38, 20)], "o")
	put(g, 4, 26, "P")
	put(g, 52, 26, "X")
	return bake(g)


## An orbit over the pit and a blade waiting on the far bank. Crossing is only
## half of it: the landing has to be timed against the saw as well.
static func _level_orbit_saw() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 22, 27, 14, 3, ".")
	rect(g, 22, 30, 14, 1, "^")
	rect(g, 28, 25, 2, 1, "r")
	rect(g, 40, 25, 1, 2, "#")
	rect(g, 50, 25, 1, 2, "#")
	put(g, 45, 26, "W")
	puts(g, [Vector2i(19, 25), Vector2i(28, 20), Vector2i(54, 25)], "o")
	put(g, 4, 26, "P")
	put(g, 56, 26, "X")
	return bake(g)


## The elastic is the lift. There is no staircase, no spring and no crystal —
## the only way up to the door is to land on something that throws you back.
static func _level_elastic_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	put(g, 22, 26, "e")
	# 96px above the floor: past what a jump plus a dash can reach on their own
	# (roughly 80px, timed as tight as the engine allows), short of what the
	# slime's bounce gives (~112px) — so the door is reachable, but only off it.
	rect(g, 34, 15, 12, 2, "#")
	puts(g, [Vector2i(14, 26), Vector2i(28, 26), Vector2i(38, 14)], "o")
	put(g, 4, 26, "P")
	put(g, 42, 14, "X")
	return bake(g)


## The elastic is penned in, and the ledge only covers the far half of its walk.
## Bouncing is easy; bouncing in the right place is the room.
static func _level_elastic_timing() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 14, 22, 2, 5, "#")
	rect(g, 40, 22, 2, 5, "#")
	put(g, 24, 26, "e")
	# Same 96px rule as elastic_first: clear of a jump-plus-dash (~80px), short
	# of the slime's bounce (~112px).
	rect(g, 30, 15, 12, 2, "#")
	puts(g, [Vector2i(8, 26), Vector2i(20, 26), Vector2i(34, 14)], "o")
	put(g, 4, 26, "P")
	put(g, 38, 14, "X")
	return bake(g)


## Two elastics, one above the other: the first throw reaches the second, and
## the second reaches the roof. The slabs on the right get there too, slowly.
static func _level_elastic_chain() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	put(g, 14, 26, "e")
	rect(g, 22, 20, 8, 1, "-")
	put(g, 26, 19, "e")
	rect(g, 40, 12, 12, 2, "#")
	rect(g, 52, 20, 6, 1, "-")
	rect(g, 46, 16, 6, 1, "-")
	puts(g, [Vector2i(26, 15), Vector2i(26, 8), Vector2i(54, 19)], "o")
	put(g, 4, 26, "P")
	put(g, 44, 11, "X")
	return bake(g)


## Spikes under everything and one elastic above them. The slabs cross the pit
## on their own, so the bounce is for the gems and for the time it saves.
static func _level_elastic_spike() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 18, 27, 24, 3, ".")
	rect(g, 18, 30, 24, 1, "^")
	rect(g, 22, 25, 4, 1, "-")
	rect(g, 30, 25, 4, 1, "-")
	rect(g, 38, 25, 3, 1, "-")
	put(g, 31, 24, "e")
	puts(g, [Vector2i(23, 20), Vector2i(31, 18), Vector2i(48, 26)], "o")
	put(g, 52, 20, "O")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## One armoured walker, a clear floor and plenty of room overhead. The room is
## a single question: the answer you have used all game does not work here.
static func _level_shield_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	put(g, 30, 26, "E")
	puts(g, [Vector2i(16, 26), Vector2i(40, 26), Vector2i(48, 26)], "o")
	put(g, 30, 20, "O")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Plain slimes and armoured ones in a row. The chain wants every head in turn;
## one of these heads has to be skipped.
static func _level_shield_mix() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	puts(g, [Vector2i(14, 26), Vector2i(30, 26), Vector2i(44, 26)], "S")
	puts(g, [Vector2i(22, 26), Vector2i(38, 26)], "E")
	puts(g, [Vector2i(18, 22), Vector2i(34, 22), Vector2i(48, 22)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## A shield under a ledge. There is no room to build up a pound beside it, so
## the drop has to start from above.
static func _level_shield_drop() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 18, 21, 24, 1, "#")
	rect(g, 12, 24, 5, 1, "-")
	put(g, 30, 26, "E")
	rect(g, 44, 27, 8, 3, ".")
	rect(g, 44, 30, 8, 1, "^")
	# The third gem sits past the shield, not on top of it. It used to share a
	# tile with the 'E', and puts() runs last, so the gem quietly deleted the
	# only shield in the room the level is named after.
	puts(g, [Vector2i(24, 20), Vector2i(36, 20), Vector2i(42, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 55, 26, "X")
	return bake(g)


## A narrow ledge over spikes with a shield already on it. Sharing the ledge is
## the difficulty; the pound clears it, but the landing has nowhere to go.
static func _level_shield_pit() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 16, 27, 28, 3, ".")
	rect(g, 16, 30, 28, 1, "^")
	rect(g, 20, 24, 20, 1, "#")
	put(g, 30, 23, "E")
	# Shield on the bridge, bat over it: one thing you cannot walk into and one
	# thing you cannot jump over, stacked on the same twenty tiles.
sda	put(g, 30, 21, "B")
	puts(g, [Vector2i(22, 23), Vector2i(38, 23), Vector2i(50, 26)], "o")
	put(g, 10, 20, "O")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## The tide starts at your feet and never stops. A plain zigzag of slabs, which
## would be nothing at all if standing still were still an option.
static func _level_lava_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 29, COLS, 3, "#")
	put(g, 30, 28, "A")
	rect(g, 8, 25, 12, 1, "-")
	rect(g, 24, 22, 12, 1, "-")
	rect(g, 40, 19, 12, 1, "-")
	rect(g, 24, 16, 12, 1, "-")
	rect(g, 8, 13, 12, 1, "-")
	rect(g, 24, 10, 12, 1, "-")
	rect(g, 38, 7, 12, 2, "#")
	puts(g, [Vector2i(14, 24), Vector2i(30, 15), Vector2i(14, 12)], "o")
	put(g, 9, 24, "P")
	put(g, 42, 6, "X")
	return bake(g)


## The same shaft as THE CLIMB, with a reason not to rest in it.
static func _level_lava_climb() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 29, COLS, 3, "#")
	put(g, 30, 28, "A")
	rect(g, 22, 6, 1, 22, "#")
	rect(g, 27, 8, 1, 20, "#")
	rect(g, 2, 25, 6, 1, "-")
	rect(g, 8, 7, 15, 1, "#")
	rect(g, 27, 5, 20, 1, "#")
	# The last stretch to the door, with the lava still coming up the shaft
	# behind you. Nowhere on this ledge is a place to wait it out.
	put(g, 32, 3, "B")
	puts(g, [Vector2i(24, 22), Vector2i(25, 14), Vector2i(34, 4)], "o")
	put(g, 4, 24, "P")
	put(g, 38, 4, "X")
	return bake(g)


## A wider tower, and every gem is a step off the fastest line. The tide decides
## how greedy you get to be.
static func _level_lava_gems() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 29, COLS, 3, "#")
	put(g, 30, 28, "A")
	rect(g, 6, 25, 10, 1, "-")
	rect(g, 20, 25, 10, 1, "-")
	rect(g, 34, 22, 10, 1, "-")
	rect(g, 20, 19, 10, 1, "-")
	rect(g, 6, 16, 10, 1, "-")
	rect(g, 20, 13, 10, 1, "-")
	rect(g, 34, 10, 10, 1, "-")
	rect(g, 20, 7, 14, 2, "#")
	puts(g, [Vector2i(10, 24), Vector2i(38, 21), Vector2i(10, 15)], "o")
	put(g, 50, 12, "O")
	put(g, 8, 24, "P")
	put(g, 26, 6, "X")
	return bake(g)


## "name" and "hint" are translation keys, not text — every screen that shows
## them runs them through Lang.t() so a language switch needs no rebuild here.
static func all() -> Array:
	var list: Array = _campaign()
	# Rooms dropped into res://rooms/ join the campaign at the end, in filename
	# order. That folder is how a sandbox room becomes an official one: export
	# it, copy the file in, and the game finds it at boot with no code change.
	list.append_array(Sandbox.pack_rooms())
	return list


static func _campaign() -> Array:
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
			"id": "ice_slime",
			"name": "level.ice_slime.name",
			"hint": "level.ice_slime.hint",
			"par": 50.0,
			"rows": _level_ice_slime(),
		},
		{
			"id": "ice_wall",
			"name": "level.ice_wall.name",
			"hint": "level.ice_wall.hint",
			"par": 46.0,
			"rows": _level_ice_wall(),
		},
		{
			"id": "belt_first",
			"name": "level.belt_first.name",
			"hint": "level.belt_first.hint",
			"par": 20.0,
			"rows": _level_belt_first(),
		},
		{
			"id": "belt_against",
			"name": "level.belt_against.name",
			"hint": "level.belt_against.hint",
			"par": 30.0,
			"rows": _level_belt_against(),
		},
		{
			"id": "belt_launch",
			"name": "level.belt_launch.name",
			"hint": "level.belt_launch.hint",
			"par": 32.0,
			"rows": _level_belt_launch(),
		},
		{
			"id": "belt_mix",
			"name": "level.belt_mix.name",
			"hint": "level.belt_mix.hint",
			"par": 42.0,
			"rows": _level_belt_mix(),
		},
		{
			"id": "retract_first",
			"name": "level.retract_first.name",
			"hint": "level.retract_first.hint",
			"par": 26.0,
			"rows": _level_retract_first(),
		},
		{
			"id": "retract_run",
			"name": "level.retract_run.name",
			"hint": "level.retract_run.hint",
			"par": 34.0,
			"rows": _level_retract_run(),
		},
		{
			"id": "retract_drop",
			"name": "level.retract_drop.name",
			"hint": "level.retract_drop.hint",
			"par": 40.0,
			"rows": _level_retract_drop(),
		},
		{
			"id": "retract_saw",
			"name": "level.retract_saw.name",
			"hint": "level.retract_saw.hint",
			"par": 48.0,
			"rows": _level_retract_saw(),
		},
		{
			"id": "orbit_first",
			"name": "level.orbit_first.name",
			"hint": "level.orbit_first.hint",
			"par": 30.0,
			"rows": _level_orbit_first(),
		},
		{
			"id": "orbit_gems",
			"name": "level.orbit_gems.name",
			"hint": "level.orbit_gems.hint",
			"par": 44.0,
			"rows": _level_orbit_gems(),
		},
		{
			"id": "orbit_saw",
			"name": "level.orbit_saw.name",
			"hint": "level.orbit_saw.hint",
			"par": 50.0,
			"rows": _level_orbit_saw(),
		},
		{
			"id": "elastic_first",
			"name": "level.elastic_first.name",
			"hint": "level.elastic_first.hint",
			"par": 36.0,
			"rows": _level_elastic_first(),
		},
		{
			"id": "elastic_timing",
			"name": "level.elastic_timing.name",
			"hint": "level.elastic_timing.hint",
			"par": 46.0,
			"rows": _level_elastic_timing(),
		},
		{
			"id": "elastic_chain",
			"name": "level.elastic_chain.name",
			"hint": "level.elastic_chain.hint",
			"par": 55.0,
			"rows": _level_elastic_chain(),
		},
		{
			"id": "elastic_spike",
			"name": "level.elastic_spike.name",
			"hint": "level.elastic_spike.hint",
			"par": 55.0,
			"rows": _level_elastic_spike(),
		},
		{
			"id": "shield_first",
			"name": "level.shield_first.name",
			"hint": "level.shield_first.hint",
			"par": 30.0,
			"rows": _level_shield_first(),
		},
		{
			"id": "shield_mix",
			"name": "level.shield_mix.name",
			"hint": "level.shield_mix.hint",
			"par": 44.0,
			"rows": _level_shield_mix(),
		},
		{
			"id": "shield_drop",
			"name": "level.shield_drop.name",
			"hint": "level.shield_drop.hint",
			"par": 48.0,
			"rows": _level_shield_drop(),
		},
		{
			"id": "shield_pit",
			"name": "level.shield_pit.name",
			"hint": "level.shield_pit.hint",
			"par": 52.0,
			"rows": _level_shield_pit(),
		},
		{
			"id": "lava_first",
			"name": "level.lava_first.name",
			"hint": "level.lava_first.hint",
			"par": 40.0,
			"rows": _level_lava_first(),
		},
		{
			"id": "lava_climb",
			"name": "level.lava_climb.name",
			"hint": "level.lava_climb.hint",
			"par": 48.0,
			"rows": _level_lava_climb(),
		},
		{
			"id": "lava_gems",
			"name": "level.lava_gems.name",
			"hint": "level.lava_gems.hint",
			"par": 58.0,
			"rows": _level_lava_gems(),
		},
	]


static func count() -> int:
	return all().size()


## Room ids in campaign order, built once.
##
## all() repaints all 36 rooms every time it is called — about 23 ms — and the
## save file asks which id sits at an index on every single query, several times
## per room per frame on the level select. Caching the ids turns that screen
## from seconds per frame back into nothing.
static var _ids := PackedStringArray()


static func ids() -> PackedStringArray:
	if _ids.is_empty():
		for room: Dictionary in all():
			_ids.append(String(room.get("id", "")))
	return _ids


static func index_of(room_id: String) -> int:
	return ids().find(room_id)
