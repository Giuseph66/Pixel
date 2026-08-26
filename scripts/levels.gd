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


## Step 11 — remix. Only tiles whose meaning depends on which way they face
## need an entry: everything else reads the same from either side.
const MIRROR_PAIRS := {">": "<", "<": ">"}


## A horizontal flip of the whole room. Row order is untouched; each row is
## reversed and run through MIRROR_PAIRS so a belt still pushes the way its
## picture points.
##
## The door needs one more correction after the reversal. 'X' is drawn offset
## +TILE*0.5 from its own tile (level.gd centres a 12px sprite so it hangs over
## the tile to its right and the one above). A plain reversal moves the tile
## but not which side the sprite hangs off, so the frame ends up floating a
## tile short of the terrain it was built against. Nudging the reversed X one
## column further left is what puts it back in the corridor it was built for.
static func mirror(rows: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for row: String in rows:
		var line := ""
		for i in range(row.length() - 1, -1, -1):
			var ch := row[i]
			line += String(MIRROR_PAIRS.get(ch, ch))
		out.append(line)

	for y in out.size():
		var x := out[y].find("X")
		if x <= 0:
			continue
		# Only when the door still has something to stand on afterwards. A door
		# built on the last tile of its slab reverses onto that slab's first
		# tile, and nudging it one further walks it off the end into the drop
		# the slab was there to finish — a correction to how the frame is
		# drawn is not worth breaking where the frame actually sits.
		var below := "#" if y + 1 >= out.size() else out[y + 1][x - 1]
		if below != "#" and below != "-" and below != "~" \
				and below != ">" and below != "<":
			continue
		var line := out[y]
		line[x] = "."
		line[x - 1] = "X"
		out[y] = line
	return out


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
## Built in the sandbox editor and brought back in, which is why it is the one
## room in here with no plain ground anywhere: the shell, the ledges and the
## walls are all ice. Nothing holds, and the floor between the two landings is
## fifty tiles of spike.
static func _level_ice_parkour() -> PackedStringArray:
	var g := blank()
	# The shell. The right wall is the only surface left that grips.
	rect(g, 0, 0, COLS, 1, "~")
	rect(g, 0, ROWS - 1, COLS, 1, "~")
	rect(g, 0, 0, 1, ROWS, "~")

	# Two landings with the pit between them.
	rect(g, 0, 27, 4, 4, "~")
	rect(g, 54, 27, 6, 4, "~")
	rect(g, 4, 30, 50, 1, "^")

	# The shelf the door stands on, back above the spawn.
	rect(g, 0, 5, 8, 1, "~")

	# The climb: (column, row, width), roughly in the order they are taken.
	for ledge: Vector3i in [
		Vector3i(9, 25, 3), Vector3i(17, 23, 3), Vector3i(48, 24, 3),
		Vector3i(38, 22, 3), Vector3i(28, 19, 3), Vector3i(13, 10, 3),
		Vector3i(3, 9, 2), Vector3i(24, 9, 3), Vector3i(33, 9, 3),
		Vector3i(41, 10, 3), Vector3i(50, 10, 1),
	]:
		rect(g, ledge.x, ledge.y, ledge.z, 1, "~")

	# The one column tall enough to catch a fall on the right-hand side.
	rect(g, 51, 21, 2, 3, "~")

	puts(g, [Vector2i(4, 8), Vector2i(26, 8), Vector2i(49, 23)], "o")
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
	put(g, 30, 21, "B")
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


## Step 10 — combo. Playgrounds, not tests: nothing here kills, so the reward
## for chaining moves is purely the number and the reach it buys, never survival.

## Two walls, three slimes, a spring, two crystals: everything the combo can
## chain through, laid out with nothing that punishes standing on the floor.
## The high gems only come down to whoever links wall jumps and the dash.
static func _level_combo_yard() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 12, 10, 2, 14, "#")           # left wall for wall jumps
	rect(g, 46, 10, 2, 14, "#")           # right wall
	puts(g, [Vector2i(18, 26), Vector2i(28, 26), Vector2i(42, 26)], "S")
	put(g, 34, 26, "J")
	puts(g, [Vector2i(24, 16), Vector2i(36, 16)], "d")
	puts(g, [Vector2i(16, 8), Vector2i(30, 6), Vector2i(44, 8)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## A spike bed wider than any single move crosses. A spring alone reaches the
## far shelf; two wall posts inside the pit turn the same crossing into a
## wall-jump chain instead, and a crystal overhead lets a dash carry the rest.
static func _level_combo_gap() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, 16, 5, "#")
	rect(g, 44, 27, COLS - 44, 5, "#")
	rect(g, 16, 30, 28, 1, "^")
	rect(g, 23, 14, 2, 16, "#")
	rect(g, 37, 14, 2, 16, "#")
	put(g, 12, 26, "J")
	rect(g, 28, 21, 5, 1, "-")
	put(g, 30, 15, "d")
	puts(g, [Vector2i(30, 19), Vector2i(42, 12)], "o")
	put(g, 4, 26, "P")
	put(g, 50, 26, "X")
	return bake(g)


## Both routes reach the same bridge. One is a wall-jump shaft straight up from
## the spawn; the other is a staircase that wanders across half the room to get
## there on foot. The par is set for the shaft — walking is a legitimate way to
## finish, just not a fast one.
static func _level_combo_tower() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 10, 6, 1, 21, "#")            # shaft, left wall
	rect(g, 15, 6, 1, 21, "#")            # shaft, right wall
	rect(g, 10, 5, 49, 1, "-")            # bridge, shaft top to the door
	rect(g, 22, 23, 5, 1, "-")
	rect(g, 30, 19, 5, 1, "-")
	rect(g, 22, 15, 5, 1, "-")
	rect(g, 30, 11, 5, 1, "-")
	rect(g, 22, 7, 5, 1, "-")
	puts(g, [Vector2i(24, 21), Vector2i(32, 9)], "o")
	put(g, 12, 3, "o")
	put(g, 4, 26, "P")
	put(g, 56, 4, "X")
	return bake(g)


## Step 12 — interruptores e portas. Every gate in a room shares one boolean:
## Level.switch_state. 'g' starts solid, 'G' starts open; either kind flips on
## the same press, which is what makes opening one path close another for free.

## The button is in plain sight of the door it opens. The whole room is one
## sentence: this causes that.
static func _level_switch_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 34, 20, 2, 7, "g")             # the wall that seals the corridor
	put(g, 26, 26, "i")
	puts(g, [Vector2i(20, 25), Vector2i(44, 25), Vector2i(50, 22)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## An open door and a closed one, back to back. The switch trades one for the
## other in the same press: what let you in seals behind you the instant what
## lets you out unseals ahead.
static func _level_switch_trade() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 18, 18, 2, 9, "G")             # starts open — the way in
	put(g, 26, 26, "i")
	rect(g, 38, 18, 2, 9, "g")             # starts closed — opens after the switch
	puts(g, [Vector2i(12, 25), Vector2i(30, 26), Vector2i(48, 25)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## The gate is right at the start; the button that opens it is a whole detour
## away. Getting there and back costs more time than the room's floor plan
## suggests, which is the toll this mechanic charges when it is not solving a
## puzzle so much as gatekeeping a shortcut.
static func _level_switch_run() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 10, 20, 2, 7, "g")
	rect(g, 6, 24, 3, 1, "-")
	rect(g, 6, 21, 3, 1, "-")
	rect(g, 6, 18, 3, 1, "-")
	rect(g, 6, 15, 3, 1, "-")
	rect(g, 6, 12, 44, 1, "-")             # the long bridge back over the gate
	put(g, 46, 11, "i")
	puts(g, [Vector2i(30, 11), Vector2i(20, 25), Vector2i(40, 25)], "o")
	put(g, 4, 26, "P")
	put(g, 16, 26, "X")
	return bake(g)


## A penned saw between the spawn and the button — the switch is not the only
## thing paying attention in this room.
static func _level_switch_saw() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 12, 25, 1, 2, "#")
	rect(g, 24, 25, 1, 2, "#")
	put(g, 18, 26, "W")
	rect(g, 38, 20, 2, 7, "g")
	put(g, 30, 26, "i")
	puts(g, [Vector2i(20, 24), Vector2i(44, 25), Vector2i(50, 22)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Two hatches in the floor instead of two walls. One starts open — drop in for
## its gem before the switch seals it. The other starts sealed and only opens
## once that same switch has been pressed, holding two gems the first hatch
## never could.
static func _level_switch_gems() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	put(g, 20, 27, "G")                    # hatch A — starts open
	rect(g, 18, 28, 5, 2, ".")
	put(g, 20, 29, "o")
	put(g, 30, 26, "i")
	put(g, 42, 27, "g")                    # hatch B — starts sealed
	rect(g, 40, 28, 5, 2, ".")
	puts(g, [Vector2i(41, 29), Vector2i(44, 29)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Step 13 — correntes de vento. 'u' is a column that pushes up, 'U' a band
## that always pushes left — a headwind, since the only direction this game
## ever asks you to travel is right. PUSH_UP sits under gravity on purpose:
## riding one still falls, just slowly enough to cross what a jump alone
## cannot.

## The gap is wider than a jump; the column is what closes the difference.
static func _level_wind_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 22, 24, 14, 6, ".")
	rect(g, 22, 30, 14, 1, "^")
	rect(g, 28, 14, 2, 13, "u")
	put(g, 29, 12, "o")
	put(g, 4, 26, "P")
	put(g, 46, 26, "X")
	return bake(g)


## Three columns, three ledges, each one a little higher. The exit sits on the
## last ledge — there is no route up that skips the climb.
static func _level_wind_climb() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 8, 20, 2, 7, "u")
	rect(g, 10, 19, 6, 1, "-")
	rect(g, 24, 13, 2, 7, "u")
	rect(g, 26, 12, 6, 1, "-")
	rect(g, 40, 6, 2, 7, "u")
	rect(g, 42, 5, 12, 1, "-")
	puts(g, [Vector2i(12, 17), Vector2i(28, 10)], "o")
	put(g, 46, 4, "o")
	put(g, 4, 26, "P")
	put(g, 50, 4, "X")
	return bake(g)


## A spiked pit under a row of one-way slabs, and a headwind the whole width of
## it. Every hop across has to fight the push rather than just clear the gap.
static func _level_wind_cross() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 12, 27, 36, 3, ".")
	rect(g, 12, 30, 36, 1, "^")
	rect(g, 12, 20, 36, 7, "U")
	rect(g, 14, 24, 8, 1, "-")
	rect(g, 26, 24, 8, 1, "-")
	rect(g, 38, 24, 8, 1, "-")
	puts(g, [Vector2i(18, 22), Vector2i(30, 22), Vector2i(42, 22)], "o")
	put(g, 4, 26, "P")
	put(g, 50, 26, "X")
	return bake(g)


## A column standing directly over a spiked pit, starting right at the takeoff
## edge. Ride it and the crossing is generous; drift off it and the pit is
## exactly as unforgiving as ever.
##
## The column used to start eight tiles into the pit instead of at its edge —
## out of jump range even before the wind could do anything, which made the
## room the "impossible" one this same plan flagged as never having been
## played by a human. A run-and-jump physics simulation (not a real playtest,
## but the numbers this game's jump is built from) puts the generous limit of
## a running jump through a floor-to-ceiling column at 27-31 tiles; the pit
## here is 20, for real margin rather than a room that is merely "solvable".
static func _level_wind_spike() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 18, 27, 20, 3, ".")
	rect(g, 18, 30, 20, 1, "^")
	rect(g, 19, 3, 5, 24, "u")
	puts(g, [Vector2i(21, 6), Vector2i(30, 25)], "o")
	put(g, 4, 26, "P")
	put(g, 44, 26, "X")
	return bake(g)


## Step 14 — bloco de fase. Solid, except for the 0.14s a dash is in the air —
## DASH_TIME * DASH_SPEED covers about four tiles, so three tiles is the
## thickest one of these should ever be built.

## A wall, a floor on both sides. The room is one question: does the dash
## really go through that?
static func _level_phase_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 30, 20, 2, 7, "p")
	puts(g, [Vector2i(20, 26), Vector2i(40, 26), Vector2i(48, 24)], "o")
	put(g, 4, 26, "P")
	put(g, 52, 26, "X")
	return bake(g)


## A bridge over the top, or two phase walls straight through — the floor
## between them refills the dash for free, so the short way costs nothing but
## the nerve to take it.
static func _level_phase_choice() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 16, 20, 2, 7, "p")
	rect(g, 34, 20, 2, 7, "p")
	rect(g, 8, 13, 2, 14, "#")
	rect(g, 48, 13, 2, 14, "#")
	rect(g, 10, 10, 40, 1, "-")
	puts(g, [Vector2i(24, 26), Vector2i(44, 26), Vector2i(28, 8)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## One continuous pit under three phase walls. There is no ground to touch
## between them — only the crystals give the dash back, and there are two of
## them for three walls.
static func _level_phase_crystal() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 12, 27, 36, 3, ".")
	rect(g, 12, 30, 36, 1, "^")
	rect(g, 14, 20, 2, 7, "p")
	put(g, 18, 23, "d")
	rect(g, 25, 20, 2, 7, "p")
	put(g, 29, 23, "d")
	rect(g, 36, 20, 2, 7, "p")
	puts(g, [Vector2i(21, 22), Vector2i(48, 24)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Three tiles — the limit — and barely anywhere to land. Failing here just
## means bumping into a wall; the room's only job is to say how far is too far.
static func _level_phase_trap() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 30, 20, 3, 7, "p")
	puts(g, [Vector2i(20, 26), Vector2i(44, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 50, 26, "X")
	return bake(g)


## A gem sealed in a nook with no other way in. The wall around it never
## moves; only the phase panel set into one side of it ever does.
static func _level_phase_gems() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 30, 19, 8, 9, "#")
	rect(g, 32, 22, 4, 4, ".")
	rect(g, 30, 22, 2, 4, "p")
	put(g, 34, 25, "o")
	puts(g, [Vector2i(16, 26), Vector2i(46, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Step 15 — portais. 'q' and 'Q' are one pair; speed carries through and
## heading becomes whichever way the exit is aimed — see
## Level._portal_facing(). Only one pair per room, on purpose: a second pair
## needs a way to say which entrance matches which exit, and this game has no
## grammar for that.

## A wall from ceiling to floor. The pair is the only way across, both ends
## facing the same way, so the crossing reads as a straight walk with a wall
## in the middle of it.
static func _level_portal_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 30, 1, 2, 26, "#")
	put(g, 29, 26, "q")
	put(g, 32, 26, "Q")
	puts(g, [Vector2i(20, 26), Vector2i(40, 26), Vector2i(50, 24)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## A floor portal at the bottom of a shaft, and its twin on a ledge partway up
## the same shaft. Falling in builds speed the fall alone never would have let
## you keep — the twin launches you back up with all of it.
static func _level_portal_fall() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	# Walls run all the way to the floor tile itself. Stopping one tile short
	# used to leave an 8px gap under them — narrower than the player's own
	# 10px height, so it read as an open crawlspace but nothing could fit
	# through it. Sealed, the portal is the only way across on purpose.
	rect(g, 24, 4, 2, 23, "#")
	rect(g, 38, 4, 2, 23, "#")
	rect(g, 26, 8, 10, 1, "-")
	put(g, 30, 26, "q")
	put(g, 30, 7, "Q")
	puts(g, [Vector2i(30, 6), Vector2i(20, 26), Vector2i(46, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## The entrance sits in a wall, the exit sits on a ledge. Speed carries over
## unchanged; only the direction changes, and a horizontal run becomes a
## vertical launch because that is the only thing the exit is aimed at.
static func _level_portal_turn() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 28, 20, 2, 7, "#")
	put(g, 27, 26, "q")
	rect(g, 38, 6, 16, 1, "#")
	put(g, 40, 5, "Q")
	puts(g, [Vector2i(48, 4), Vector2i(20, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 52, 5, "X")
	return bake(g)


## A single climbable post, not a pair of walls sealing off a corridor — this
## used to share portal_fall's shape almost tile for tile, just relabelled.
## The climb ends in open air with nothing on the other side: the fall is
## twenty-two tiles, built entirely to feed the launch on the far end, and the
## floor underneath stays walkable the whole width of the room. Both portal
## ends face up, so all that fall becomes height on the way back out.
static func _level_portal_gem() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 8, 6, 2, 20, "#")
	rect(g, 4, 22, 4, 1, "-")
	rect(g, 4, 16, 4, 1, "-")
	rect(g, 4, 10, 4, 1, "-")
	rect(g, 6, 5, 6, 1, "-")
	put(g, 22, 26, "q")
	rect(g, 40, 22, 6, 1, "-")
	put(g, 43, 21, "Q")
	put(g, 43, 8, "o")
	puts(g, [Vector2i(30, 26), Vector2i(50, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## The entrance sits inside a saw's own pen. Timing the crossing is timing the
## blade, not the portal.
static func _level_portal_saw() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 26, 25, 1, 2, "#")
	rect(g, 34, 25, 1, 2, "#")
	put(g, 30, 26, "W")
	put(g, 27, 26, "q")
	rect(g, 44, 20, 2, 7, "#")
	put(g, 45, 26, "Q")
	puts(g, [Vector2i(20, 26), Vector2i(50, 24)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Step 16 — lasers telegrafados. Sleep, then a 0.5s blink, then 0.6s of a
## beam that reaches until the first wall. The blink is the whole fairness of
## the mechanic; nothing here ever shortens it.

## One emitter, one wall to bounce off, floor the whole way across. The room
## asks for nothing but reading the cycle once.
static func _level_laser_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 22, 14, 2, 9, "#")
	put(g, 24, 22, "L")
	rect(g, 44, 14, 2, 13, "#")
	puts(g, [Vector2i(32, 26), Vector2i(38, 26), Vector2i(50, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## A low beam over the first pit's jump, a high one over the ledge after it.
## The floor route is safe from both; the two things that are not the floor
## are not safe from either.
static func _level_laser_stack() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 20, 27, 6, 3, ".")
	rect(g, 20, 30, 6, 1, "^")
	rect(g, 12, 17, 2, 10, "#")
	put(g, 14, 22, "L")
	rect(g, 40, 27, 6, 3, ".")
	rect(g, 40, 30, 6, 1, "^")
	rect(g, 42, 20, 10, 1, "-")
	rect(g, 34, 4, 2, 15, "#")
	put(g, 36, 10, "L")
	puts(g, [Vector2i(28, 26), Vector2i(46, 19)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## A wall-jump shaft with three emitters staggered up it, alternating sides.
## Every jump between the walls has its own window cut out of the cycle.
static func _level_laser_climb() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 24, 4, 2, 22, "#")
	rect(g, 34, 4, 2, 22, "#")
	put(g, 26, 22, "L")
	put(g, 33, 15, "L")
	put(g, 26, 8, "L")
	rect(g, 24, 3, 12, 1, "#")
	puts(g, [Vector2i(29, 18), Vector2i(29, 11)], "o")
	put(g, 4, 26, "P")
	put(g, 30, 2, "X")
	return bake(g)


## The step 12 switch, doing something new: a press freezes every laser in the
## room for four seconds instead of a gate opening. The corridor is the same
## corridor either way — only the timing changes.
static func _level_laser_gate() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	put(g, 10, 26, "i")
	rect(g, 20, 20, 2, 7, "#")
	put(g, 22, 24, "L")
	rect(g, 44, 20, 2, 7, "#")
	puts(g, [Vector2i(30, 26), Vector2i(50, 24)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)


## Step 17 — morcego transportador. 'F' patrols and carries whoever stands on
## it, and drops out from under them CARRY_TIME after they board — see
## ferry_bat.gd. Its sides and underside stay lethal the whole time; only the
## top is ever a ride.

## A gap nothing jumps, and one bat that crosses it. Nothing else in the room.
static func _level_ferry_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 18, 24, 24, 7, ".")
	put(g, 30, 20, "F")
	put(g, 30, 16, "o")
	put(g, 4, 26, "P")
	put(g, 48, 26, "X")
	return bake(g)


## Two bats, patrols wide enough to overlap in the middle. Crossing means
## jumping from one to the other rather than riding either one the whole way.
static func _level_ferry_hop() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 14, 22, 32, 9, ".")
	put(g, 22, 20, "F")
	put(g, 38, 20, "F")
	puts(g, [Vector2i(30, 14), Vector2i(20, 26), Vector2i(46, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 50, 26, "X")
	return bake(g)


## A gap wide enough that the first bat's deadline runs out before it gets
## you all the way across — the second one is what finishes the crossing, not
## a second attempt at the first.
static func _level_ferry_dive() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 14, 22, 38, 9, ".")
	put(g, 22, 20, "F")
	put(g, 42, 20, "F")
	puts(g, [Vector2i(32, 14), Vector2i(20, 26), Vector2i(48, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 52, 26, "X")
	return bake(g)


## The same crossing, over spikes instead of a harmless drop. Missing the
## ride here is not an inconvenience.
static func _level_ferry_spike() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 16, 27, 28, 3, ".")
	rect(g, 16, 30, 28, 1, "^")
	put(g, 30, 20, "F")
	puts(g, [Vector2i(30, 16), Vector2i(20, 26), Vector2i(44, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 48, 26, "X")
	return bake(g)


## Step 18 — pulo carregado. Standing still on the ground for CHARGE_TIME
## (0.35s) makes the next jump climb about 7.9 tiles instead of 4.7. No tile
## of its own and no infinite-mode segment — the generator's steps and gaps
## are all sized for the normal jump, and a charge is a bonus escape from a
## mistake, never something a generated room is built to require.

## Six tiles up, nothing else in the room. The only question the room asks is
## whether you know the move exists.
static func _level_charge_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 34, 21, 14, 6, "#")
	put(g, 40, 20, "o")
	put(g, 4, 26, "P")
	put(g, 44, 20, "X")
	return bake(g)


## Three tall steps. The first and the last give a wide landing to charge on;
## the middle one is narrow enough that stopping on it at all is the hard part.
static func _level_charge_gap() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 12, 21, 8, 6, "#")
	rect(g, 26, 15, 3, 12, "#")
	rect(g, 36, 9, 8, 18, "#")
	puts(g, [Vector2i(15, 20), Vector2i(38, 8)], "o")
	put(g, 4, 26, "P")
	put(g, 40, 8, "X")
	return bake(g)


## Two routes to the same door: a short climb that costs two charges (0.7s
## stood still), or a long way around at floor level and up a staircase that
## never asks you to stop moving. Neither route is wrong.
static func _level_charge_race() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 16, 21, 6, 6, "#")
	rect(g, 30, 15, 6, 6, "#")
	rect(g, 36, 15, 19, 1, "-")
	rect(g, 44, 24, 4, 1, "-")
	rect(g, 50, 20, 4, 1, "-")
	puts(g, [Vector2i(19, 20), Vector2i(33, 14)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 14, "X")
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
			# A different room in this slot, so it takes a new id rather than
			# inheriting the best times somebody set on the old one.
			"id": "ice_parkour",
			"name": "level.ice_parkour.name",
			"hint": "level.ice_parkour.hint",
			"par": 46.0,
			"rows": _level_ice_parkour(),
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
		{
			"id": "combo_yard",
			"name": "level.combo_yard.name",
			"hint": "level.combo_yard.hint",
			"par": 30.0,
			"rows": _level_combo_yard(),
		},
		{
			"id": "combo_gap",
			"name": "level.combo_gap.name",
			"hint": "level.combo_gap.hint",
			"par": 38.0,
			"rows": _level_combo_gap(),
		},
		{
			"id": "combo_tower",
			"name": "level.combo_tower.name",
			"hint": "level.combo_tower.hint",
			"par": 40.0,
			"rows": _level_combo_tower(),
		},
		{
			"id": "switch_first",
			"name": "level.switch_first.name",
			"hint": "level.switch_first.hint",
			"par": 30.0,
			"rows": _level_switch_first(),
		},
		{
			"id": "switch_trade",
			"name": "level.switch_trade.name",
			"hint": "level.switch_trade.hint",
			"par": 42.0,
			"rows": _level_switch_trade(),
		},
		{
			"id": "switch_run",
			"name": "level.switch_run.name",
			"hint": "level.switch_run.hint",
			"par": 48.0,
			"rows": _level_switch_run(),
		},
		{
			"id": "switch_saw",
			"name": "level.switch_saw.name",
			"hint": "level.switch_saw.hint",
			"par": 46.0,
			"rows": _level_switch_saw(),
		},
		{
			"id": "switch_gems",
			"name": "level.switch_gems.name",
			"hint": "level.switch_gems.hint",
			"par": 58.0,
			"rows": _level_switch_gems(),
		},
		{
			"id": "wind_first",
			"name": "level.wind_first.name",
			"hint": "level.wind_first.hint",
			"par": 28.0,
			"rows": _level_wind_first(),
		},
		{
			"id": "wind_climb",
			"name": "level.wind_climb.name",
			"hint": "level.wind_climb.hint",
			"par": 42.0,
			"rows": _level_wind_climb(),
		},
		{
			"id": "wind_cross",
			"name": "level.wind_cross.name",
			"hint": "level.wind_cross.hint",
			"par": 46.0,
			"rows": _level_wind_cross(),
		},
		{
			"id": "wind_spike",
			"name": "level.wind_spike.name",
			"hint": "level.wind_spike.hint",
			"par": 50.0,
			"rows": _level_wind_spike(),
		},
		{
			"id": "phase_first",
			"name": "level.phase_first.name",
			"hint": "level.phase_first.hint",
			"par": 22.0,
			"rows": _level_phase_first(),
		},
		{
			"id": "phase_choice",
			"name": "level.phase_choice.name",
			"hint": "level.phase_choice.hint",
			"par": 40.0,
			"rows": _level_phase_choice(),
		},
		{
			"id": "phase_crystal",
			"name": "level.phase_crystal.name",
			"hint": "level.phase_crystal.hint",
			"par": 48.0,
			"rows": _level_phase_crystal(),
		},
		{
			"id": "phase_trap",
			"name": "level.phase_trap.name",
			"hint": "level.phase_trap.hint",
			"par": 44.0,
			"rows": _level_phase_trap(),
		},
		{
			"id": "phase_gems",
			"name": "level.phase_gems.name",
			"hint": "level.phase_gems.hint",
			"par": 50.0,
			"rows": _level_phase_gems(),
		},
		{
			"id": "portal_first",
			"name": "level.portal_first.name",
			"hint": "level.portal_first.hint",
			"par": 26.0,
			"rows": _level_portal_first(),
		},
		{
			"id": "portal_fall",
			"name": "level.portal_fall.name",
			"hint": "level.portal_fall.hint",
			"par": 40.0,
			"rows": _level_portal_fall(),
		},
		{
			"id": "portal_turn",
			"name": "level.portal_turn.name",
			"hint": "level.portal_turn.hint",
			"par": 44.0,
			"rows": _level_portal_turn(),
		},
		{
			"id": "portal_gem",
			"name": "level.portal_gem.name",
			"hint": "level.portal_gem.hint",
			"par": 55.0,
			"rows": _level_portal_gem(),
		},
		{
			"id": "portal_saw",
			"name": "level.portal_saw.name",
			"hint": "level.portal_saw.hint",
			"par": 50.0,
			"rows": _level_portal_saw(),
		},
		{
			"id": "laser_first",
			"name": "level.laser_first.name",
			"hint": "level.laser_first.hint",
			"par": 30.0,
			"rows": _level_laser_first(),
		},
		{
			"id": "laser_stack",
			"name": "level.laser_stack.name",
			"hint": "level.laser_stack.hint",
			"par": 44.0,
			"rows": _level_laser_stack(),
		},
		{
			"id": "laser_climb",
			"name": "level.laser_climb.name",
			"hint": "level.laser_climb.hint",
			"par": 52.0,
			"rows": _level_laser_climb(),
		},
		{
			"id": "laser_gate",
			"name": "level.laser_gate.name",
			"hint": "level.laser_gate.hint",
			"par": 50.0,
			"rows": _level_laser_gate(),
		},
		{
			"id": "ferry_first",
			"name": "level.ferry_first.name",
			"hint": "level.ferry_first.hint",
			"par": 32.0,
			"rows": _level_ferry_first(),
		},
		{
			"id": "ferry_hop",
			"name": "level.ferry_hop.name",
			"hint": "level.ferry_hop.hint",
			"par": 48.0,
			"rows": _level_ferry_hop(),
		},
		{
			"id": "ferry_dive",
			"name": "level.ferry_dive.name",
			"hint": "level.ferry_dive.hint",
			"par": 52.0,
			"rows": _level_ferry_dive(),
		},
		{
			"id": "ferry_spike",
			"name": "level.ferry_spike.name",
			"hint": "level.ferry_spike.hint",
			"par": 56.0,
			"rows": _level_ferry_spike(),
		},
		{
			"id": "charge_first",
			"name": "level.charge_first.name",
			"hint": "level.charge_first.hint",
			"par": 24.0,
			"rows": _level_charge_first(),
		},
		{
			"id": "charge_gap",
			"name": "level.charge_gap.name",
			"hint": "level.charge_gap.hint",
			"par": 38.0,
			"rows": _level_charge_gap(),
		},
		{
			"id": "charge_race",
			"name": "level.charge_race.name",
			"hint": "level.charge_race.hint",
			"par": 42.0,
			"rows": _level_charge_race(),
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
