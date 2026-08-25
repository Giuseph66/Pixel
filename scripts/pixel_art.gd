class_name PixelArt
extends RefCounted

## Every sprite in the game, stored as character grids and turned into textures
## at load time. No PNGs, no importer, no .import files — the art lives in the
## source and is built by Image.set_pixel() when the game boots.

const TILE := 8

const GRIDS := {
	"player_idle": [
		"..####..",
		".#cccc#.",
		"#cccccc#",
		"#wwccww#",
		"#w#cc#w#",
		"#cccccc#",
		"#CCCCCC#",
		".#CCCC#.",
		".#D##D#.",
		"..#..#..",
	],
	"player_run_a": [
		"..####..",
		".#cccc#.",
		"#cccccc#",
		"#wwccww#",
		"#w#cc#w#",
		"#cccccc#",
		"#CCCCCC#",
		".#CCCC#.",
		"..#DD#..",
		".##..##.",
	],
	"player_run_b": [
		"........",
		"..####..",
		".#cccc#.",
		"#cccccc#",
		"#wwccww#",
		"#w#cc#w#",
		"#cccccc#",
		"#CCCCCC#",
		".#CCCC#.",
		".#D##D#.",
	],
	"player_jump": [
		"..####..",
		".#cccc#.",
		"#cccccc#",
		"#wwccww#",
		"#w#cc#w#",
		"#cccccc#",
		"#CCCCCC#",
		"#CCCCCC#",
		".#D##D#.",
		"..#..#..",
	],
	"player_fall": [
		"........",
		"..####..",
		".#cccc#.",
		"#wwccww#",
		"#w#cc#w#",
		"#cccccc#",
		"#CCCCCC#",
		"#CCCCCC#",
		"#D#..#D#",
		".#....#.",
	],
	"player_wall": [
		"..####..",
		".#cccc#.",
		"#cccccc#",
		"#ccwwcc#",
		"#cc#w#c#",
		"#cccccc#",
		"#CCCCCC#",
		".#CCCC#.",
		".#DD##..",
		"..##....",
	],
	"slime_a": [
		"........",
		"..####..",
		".#gggg#.",
		"#gwggwg#",
		"#g#gg#g#",
		"#gggggg#",
		"#GGGGGG#",
		".######.",
	],
	"slime_b": [
		"........",
		"........",
		"..####..",
		".#gggg#.",
		"#gwggwg#",
		"#g#gg#g#",
		"#GGGGGG#",
		".######.",
	],
	"gem": [
		"..yy..",
		".ywwy.",
		"yywyyy",
		"yyyyyy",
		".yYYy.",
		"..YY..",
	],
	"spike": [
		"........",
		"...##...",
		"..#w1#..",
		"..#11#..",
		".#1112#.",
		".#1122#.",
		"#112222#",
		"#MMMMMM#",
	],
	"spring": [
		"........",
		"........",
		"........",
		"..####..",
		".#mmmm#.",
		"#mMMMMm#",
		"#MMMMMM#",
		"########",
	],
	"spring_fired": [
		"..####..",
		".#mmmm#.",
		"#mmmmmm#",
		"#mMMMMm#",
		"#MMMMMM#",
		"########",
		"........",
		"........",
	],
	"saw_a": [
		"...##...",
		"..#11#..",
		".#1111#.",
		"##11ww1#",
		"#1ww11##",
		".#1111#.",
		"..#11#..",
		"...##...",
	],
	"saw_b": [
		"..#..#..",
		".#1111#.",
		"#111111#",
		".11ww11.",
		".11ww11.",
		"#111111#",
		".#1111#.",
		"..#..#..",
	],
	"bat_a": [
		"........",
		"#p....p#",
		"#pp..pp#",
		".#pppp#.",
		"..#ww#..",
		"..#pp#..",
		"...##...",
		"........",
	],
	"bat_b": [
		"........",
		"........",
		"..#pp#..",
		".#pppp#.",
		"#p#ww#p#",
		"#pp##pp#",
		".#....#.",
		"........",
	],
	"crumble": [
		"########",
		"#122211#",
		"#122211#",
		"#111111#",
		"#112221#",
		"#112221#",
		"#122211#",
		"########",
	],
	"crumble_cracked": [
		"########",
		"#12#211#",
		"#1#2211#",
		"#11#111#",
		"#112#21#",
		"#1122#11",
		"#12#211#",
		"########",
	],
	"platform_icon": [
		"........",
		"........",
		"........",
		"########",
		"#yyyyyy#",
		"#YYYYYY#",
		"########",
		"........",
	],
	"breakable": [
		"########",
		"#YYyyYY#",
		"#Yy##yY#",
		"#yy##yy#",
		"#yy##yy#",
		"#Yy##yY#",
		"#YYyyYY#",
		"########",
	],
	"crystal": [
		"...##...",
		"..#cc#..",
		".#cwwc#.",
		"#cwwwwc#",
		"#cwwwwc#",
		".#cCCc#.",
		"..#CC#..",
		"...##...",
	],
	"crystal_used": [
		"...ff...",
		"..f..f..",
		".f....f.",
		"f......f",
		"f......f",
		".f....f.",
		"..f..f..",
		"...ff...",
	],
	"timed_on": [
		"########",
		"#pppppp#",
		"#pbbbbp#",
		"#pbbbbp#",
		"#pbbbbp#",
		"#pbbbbp#",
		"#pppppp#",
		"########",
	],
	"timed_off": [
		"ff....ff",
		"f......f",
		"........",
		"........",
		"........",
		"........",
		"f......f",
		"ff....ff",
	],
	"door": [
		"..########..",
		".#pppppppp#.",
		"#pp######pp#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#p#bbbbbb#p#",
		"#pp######pp#",
		".##########.",
	],

	# Codex icons. Every one is 8x8, exactly like the entity sprites, so the
	# book can scale all of them by the same integer factor — mixing a 12x16
	# door with 8x8 creatures made one tower over the rest.
	#
	# Abilities get pictograms rather than player poses: run, jump, wall, stomp
	# and dash are the *same* two or three sprites in the game (idle, jump,
	# fall), so a page per ability showed the same little blue figure five times
	# over. An arrow says which verb it is; a character sprite cannot.
	"icon_run": [
		"........",
		"..c..c..",
		"...c..c.",
		"....c..c",
		"...c..c.",
		"..c..c..",
		"........",
		"11111111",
	],
	"icon_jump": [
		"...cc...",
		"..cccc..",
		".cccccc.",
		"...cc...",
		"...cc...",
		"...cc...",
		"........",
		"11111111",
	],
	"icon_wall": [
		"..cc.111",
		".cccc111",
		"ccccc111",
		"..cc.111",
		"..cc.111",
		"..cc.111",
		"..cc.111",
		".....111",
	],
	"icon_stomp": [
		"...cc...",
		"...cc...",
		"...cc...",
		".cccccc.",
		"..cccc..",
		"...cc...",
		"........",
		"11.11.11",
	],
	"icon_dash": [
		"........",
		"1.......",
		".....c..",
		"......c.",
		"11cccccc",
		"......c.",
		".....c..",
		"1.......",
	],
	"icon_pound": [
		"...mm...",
		"...mm...",
		".mmmmmm.",
		"..mmmm..",
		"...mm...",
		"........",
		"11111111",
		"m......m",
	],
	# Three links climbing the same diagonal, cool to hot: the colour code the
	# in-game popup uses (cyan, gold, white) read backwards as a staircase.
	"icon_combo": [
		"......w.",
		".....ww.",
		"....yy..",
		"...yy...",
		"..cc....",
		".cc.....",
		"........",
		"........",
	],
	# The playable door is 12x16; this is its 8x8 stand-in for the book.
	"icon_door": [
		"..####..",
		".#pppp#.",
		".#pbbp#.",
		".#pbbp#.",
		".#pbbp#.",
		".#pbbp#.",
		".#pwbp#.",
		".######.",
	],
	# Open book for the corner button.
	#
	# Two things this had to get right. The outer edges run straight down: an
	# earlier attempt started the top rows inset and widened them going down,
	# which is the silhouette of two hills, not a book. Only the *top* edge
	# steps inward, and that is what reads as pages fanned open.
	#
	# The rim is gold, not OUTLINE. OUTLINE is #07070f against a #0f0f1b
	# background — darker than the thing it is meant to stand out from, so it
	# vanished and left an undefined white blob with no spine. Gold separates
	# from the background and matches the cover on the codex page.
	"icon_book": [
		"YY...........YY",
		"YwwY.......YwwY",
		"YwwwwY...YwwwwY",
		"YwwwwwY.YwwwwwY",
		"YwwwwwwYwwwwwwY",
		"Yw1111wYw1111wY",
		"YwwwwwwYwwwwwwY",
		"Yw1111wYw1111wY",
		"YwwwwwwYwwwwwwY",
		"YyyyyyyYyyyyyyY",
		".YYYYYYYYYYYYY.",
	],
	# --- ice, conveyors, retracting spikes ---
	"ice": [
		"########",
		"#wwCCCC#",
		"#wCCCCC#",
		"#CCCwCC#",
		"#CCCCCC#",
		"#CCwCCC#",
		"#CCCCCC#",
		"########",
	],
	# Four phases of one belt tile, each a pixel further along than the last.
	# The chevrons have a period of four pixels, so the fourth frame lands
	# exactly back on the first and the run scrolls without a seam. Rows are
	# lit plate, five rows of chevron, roller studs, base outline — and no side
	# edges, because a belt is drawn as one strip and any vertical line would
	# show up as a false joint every eight pixels.
	"belt_0": [
		"11111111",
		"c222c222",
		"2c222c22",
		"22c222c2",
		"2c222c22",
		"c222c222",
		"2fff2fff",
		"########",
	],
	"belt_1": [
		"11111111",
		"2c222c22",
		"22c222c2",
		"222c222c",
		"22c222c2",
		"2c222c22",
		"f2fff2ff",
		"########",
	],
	"belt_2": [
		"11111111",
		"22c222c2",
		"222c222c",
		"c222c222",
		"222c222c",
		"22c222c2",
		"ff2fff2f",
		"########",
	],
	"belt_3": [
		"11111111",
		"222c222c",
		"c222c222",
		"2c222c22",
		"c222c222",
		"222c222c",
		"fff2fff2",
		"########",
	],
	# Risen: the same silhouette as a fixed spike, so the danger reads the same.
	"spike_up": [
		"........",
		"...##...",
		"..#w1#..",
		"..#11#..",
		".#1112#.",
		".#1122#.",
		"#112222#",
		"#MMMMMM#",
	],
	# Retracted: a base plate you can walk over.
	"spike_low": [
		"........",
		"........",
		"........",
		"........",
		"........",
		"..#11#..",
		"#112222#",
		"#MMMMMM#",
	],
	# A blade that fills more than one tile is built from three pieces: the
	# point on top, shaft in the middle, and the base plate at the bottom.
	# 'spike_up' stays the whole thing at once, for the one-tile case and the
	# codex entry.
	"spike_tip": [
		"...##...",
		"..#w1#..",
		"..#11#..",
		".#1112#.",
		".#1112#.",
		".#1122#.",
		".#1122#.",
		".#1122#.",
	],
	"spike_shaft": [
		".#1122#.",
		".#w122#.",
		".#1122#.",
		".#1122#.",
		".#1122#.",
		".#w122#.",
		".#1122#.",
		".#1122#.",
	],
	"spike_base": [
		".#1122#.",
		".#1122#.",
		".#w122#.",
		".#1122#.",
		".#1122#.",
		".#1122#.",
		"#112222#",
		"#MMMMMM#",
	],
	# Step 12 — switches and gates. The lever leans toward the side it means:
	# left and dim when off, right and lit when on. Gate is a filled block
	# behind the same outline every wall has, versus an outline with nothing
	# behind it — full versus empty is the whole vocabulary a 8x8 tile has for
	# "in your way" against "not in your way any more".
	"switch_off": [
		"........",
		"..1.....",
		"..11....",
		"...11...",
		"....11..",
		"..2222..",
		".222222.",
		"........",
	],
	"switch_on": [
		"........",
		".....c..",
		"....cc..",
		"...cc...",
		"..cc....",
		"..2222..",
		".222222.",
		"........",
	],
	"gate_solid": [
		"########",
		"#yyyyyy#",
		"#yYYYYy#",
		"#yYyyYy#",
		"#yYyyYy#",
		"#yYYYYy#",
		"#yyyyyy#",
		"########",
	],
	"gate_open": [
		"########",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"########",
	],
	# Step 13 — wind. Invisible in the room itself (the particles are the
	# tell); these two exist only so the sandbox editor has something to show
	# where a designer put one.
	"wind_up": [
		"........",
		"...cc...",
		"..cccc..",
		"........",
		"...cc...",
		"..cccc..",
		"........",
		"........",
	],
	"wind_side": [
		"........",
		"..c.....",
		".cc.....",
		"cccccc..",
		".cc.....",
		"..c.....",
		"........",
		"........",
	],
	# --- shielded and elastic enemies ---
	# Same trick as the slime's walk: frame b drops one body row and shifts
	# everything down into it, so the whole plate squashes on the beat instead
	# of just the eyes flickering. Feet stay pinned to the bottom row in both.
	"shield_a": [
		"........",
		"..####..",
		"#w1111w#",
		".#gggg#.",
		"#gwggwg#",
		"#g#gg#g#",
		"#GGGGGG#",
		".######.",
	],
	"shield_b": [
		"........",
		"........",
		"..####..",
		"#w1111w#",
		"#ggwwgg#",
		"#g#gg#g#",
		"#GGGGGG#",
		".######.",
	],
	"elastic_a": [
		"........",
		"..####..",
		".#yyyy#.",
		"#ywyywy#",
		"#y#yy#y#",
		"#yyyyyy#",
		"#YYYYYY#",
		".######.",
	],
	"elastic_b": [
		"........",
		"........",
		"..####..",
		".#yyyy#.",
		"#ywyywy#",
		"#yyyyyy#",
		"#YYYYYY#",
		".######.",
	],
	# --- collectibles and medals ---
	"gem_secret": [
		"..pp..",
		".pwwp.",
		"ppwppp",
		"pppppp",
		".pMMp.",
		"..MM..",
	],
	# Drawn white and tinted at the call site, so one grid serves both the
	# earned and the unearned state.
	"medal_time": [
		"#######",
		"#wwwww#",
		"#.www.#",
		"#..w..#",
		"#.www.#",
		"#wwwww#",
		"#######",
	],
	"medal_gems": [
		"...w...",
		"..www..",
		".wwwww.",
		"wwwwwww",
		".wwwww.",
		"..www..",
		"...w...",
	],
	"medal_clean": [
		".wwwww.",
		"wwwwwww",
		"wwwwwww",
		"wwwwwww",
		".wwwww.",
		"..www..",
		"...w...",
	],
}

static var _cache: Dictionary = {}


## Texture for a named grid, built once and reused.
static func tex(name: String) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	# A missing grid used to take the whole frame down with an invalid index.
	# A loud warning and a blank texture is the better trade: the sprite is
	# obviously absent on screen and the room stays playable.
	if not GRIDS.has(name):
		push_error("PixelArt: no sprite named '%s'" % name)
		_cache[name] = from_grid(["."])
		return _cache[name]
	var t := from_grid(GRIDS[name])
	_cache[name] = t
	return t


## Small shared cache for textures that are built rather than drawn from a grid
## — a belt band the width of its run, for instance. Rooms rebuild on every
## death, so without this the same strip is rebaked hundreds of times.
static func has_cached(key: String) -> bool:
	return _cache.has(key)


static func cached(key: String) -> ImageTexture:
	return _cache[key]


static func store(key: String, t: ImageTexture) -> ImageTexture:
	_cache[key] = t
	return t


static func from_grid(rows: Array) -> ImageTexture:
	var h := rows.size()
	var w := 0
	for row in rows:
		w = maxi(w, (row as String).length())
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var c: Color = Palette.CHARS.get(row[x], Color(0, 0, 0, 0))
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Flat coloured rectangle, handy for bars and flashes.
static func solid(size: Vector2i, color: Color) -> ImageTexture:
	var img := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


# ----------------------------------------------------------------- tiles ---

## Paint one 8x8 terrain tile into `img`, shading its exposed edges.
## The neighbour flags say whether solid ground continues in that direction.
static func paint_tile(img: Image, tx: int, ty: int, up: bool, down: bool,
		left: bool, right: bool) -> void:
	var ox := tx * TILE
	var oy := ty * TILE

	for y in TILE:
		for x in TILE:
			img.set_pixel(ox + x, oy + y, Palette.FRAME)

	# Two speckles per tile, placed by a cheap deterministic hash so the
	# terrain has texture without ever shimmering between frames.
	var h := (tx * 73856093) ^ (ty * 19349663)
	var s1 := Vector2i(2 + absi(h) % 4, 3 + absi(h / 7) % 4)
	var s2 := Vector2i(1 + absi(h / 13) % 5, 2 + absi(h / 31) % 5)
	img.set_pixel(ox + s1.x, oy + s1.y, Palette.BG_SOFT)
	img.set_pixel(ox + s2.x, oy + s2.y, Palette.BG_SOFT)

	if not left:
		for y in TILE:
			img.set_pixel(ox, oy + y, Palette.OUTLINE)
	if not right:
		for y in TILE:
			img.set_pixel(ox + TILE - 1, oy + y, Palette.OUTLINE)
	if not down:
		for x in TILE:
			img.set_pixel(ox + x, oy + TILE - 1, Palette.OUTLINE)
	if not up:
		# Lit rim on anything you can stand on.
		for x in TILE:
			img.set_pixel(ox + x, oy, Palette.CYAN_MID)
			img.set_pixel(ox + x, oy + 1, Palette.CYAN_DARK)
		if not left:
			img.set_pixel(ox, oy, Palette.OUTLINE)
		if not right:
			img.set_pixel(ox + TILE - 1, oy, Palette.OUTLINE)


## A vertical run of ordinary wall, left edge exposed — the texture a wall you
## can cling to actually has in a room, not a flat rectangle standing in for
## it. `up` and `down` are true for every tile (the column keeps going past
## both ends), so paint_tile only outlines the exposed left face and leaves
## the lit rim for an actual floor tile to use.
static var _wall_cache: Dictionary = {}

static func wall_strip(tiles: int) -> ImageTexture:
	if _wall_cache.has(tiles):
		return _wall_cache[tiles]
	var img := Image.create_empty(TILE, TILE * tiles, false, Image.FORMAT_RGBA8)
	for ty in tiles:
		paint_tile(img, 0, ty, true, true, false, true)
	var t := ImageTexture.create_from_image(img)
	_wall_cache[tiles] = t
	return t


## One-way platform: a thin lit slab you can jump up through.
static func paint_platform(img: Image, tx: int, ty: int) -> void:
	var ox := tx * TILE
	var oy := ty * TILE
	for x in TILE:
		img.set_pixel(ox + x, oy, Palette.CYAN_MID)
		img.set_pixel(ox + x, oy + 1, Palette.CYAN_DARK)
		img.set_pixel(ox + x, oy + 2, Palette.OUTLINE)


## Ice tile: flat frozen body with a hard frost crust on any face you can land
## on. Built the same way ordinary terrain is — a solid fill plus a couple of
## hash-placed marks — so it sits in the same art, and the cyan plus the bright
## top are what tell you it is slippery before you step on it.
static func paint_ice(img: Image, tx: int, ty: int, up: bool, down: bool,
		left: bool, right: bool) -> void:
	var ox := tx * TILE
	var oy := ty * TILE

	for y in TILE:
		for x in TILE:
			img.set_pixel(ox + x, oy + y, Palette.CYAN_DARK)

	# Deterministic marks, same trick as paint_tile: texture that never
	# shimmers between frames because it is derived from the tile position.
	var h := absi((tx * 374761393) ^ (ty * 668265263))
	img.set_pixel(ox + 1 + h % 5, oy + 2 + (h / 7) % 4, Palette.CYAN_MID)
	img.set_pixel(ox + 2 + (h / 13) % 4, oy + 3 + (h / 31) % 4, Palette.CYAN_MID)

	# Every third tile or so catches a glint: a small cross, bright in the
	# middle. Sparse on purpose — a sparkle on every tile reads as noise.
	if h % 3 == 0:
		var cx := 2 + (h / 61) % 4
		var cy := 3 + (h / 97) % 3
		img.set_pixel(ox + cx, oy + cy, Palette.WHITE)
		img.set_pixel(ox + cx - 1, oy + cy, Palette.CYAN_MID)
		img.set_pixel(ox + cx + 1, oy + cy, Palette.CYAN_MID)
		img.set_pixel(ox + cx, oy + cy - 1, Palette.CYAN_MID)
		img.set_pixel(ox + cx, oy + cy + 1, Palette.CYAN_MID)

	if not left:
		for y in TILE:
			img.set_pixel(ox, oy + y, Palette.OUTLINE)
	if not right:
		for y in TILE:
			img.set_pixel(ox + TILE - 1, oy + y, Palette.OUTLINE)
	if not down:
		for x in TILE:
			img.set_pixel(ox + x, oy + TILE - 1, Palette.OUTLINE)
	if not up:
		# Frost crust: a hard white lip over a cyan band, brighter than the
		# lit rim on plain terrain so the two never get confused mid-run.
		for x in TILE:
			img.set_pixel(ox + x, oy, Palette.WHITE)
			img.set_pixel(ox + x, oy + 1, Palette.CYAN)
		if not left:
			img.set_pixel(ox, oy, Palette.OUTLINE)
		if not right:
			img.set_pixel(ox + TILE - 1, oy, Palette.OUTLINE)


# ------------------------------------------------------------- title cube ---

## The logo cube, rebuilt from the same maths as logo/make_logo.py.
static func cube(size_faces: int = 8) -> ImageTexture:
	var side := size_faces
	var img := Image.create_empty(18, 8 + side + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ox := 1
	var oy := 1

	for r in 8:
		var half := r if r < 4 else 7 - r
		var x0 := 7 - (half * 2 + 1)
		var x1 := 8 + (half * 2 + 1)
		for x in range(x0, x1 + 1):
			img.set_pixel(ox + x, oy + r, Palette.CYAN)

	for x in 8:
		var ytop := 4 + x / 2
		for y in range(ytop, ytop + side):
			img.set_pixel(ox + x, oy + y, Palette.CYAN_MID)
	for x in range(8, 16):
		var ytop := 4 + (15 - x) / 2
		for y in range(ytop, ytop + side):
			img.set_pixel(ox + x, oy + y, Palette.CYAN_DARK)

	for p: Vector2i in [Vector2i(5, 2), Vector2i(6, 2), Vector2i(4, 3), Vector2i(5, 3), Vector2i(7, 1)]:
		img.set_pixel(ox + p.x, oy + p.y, Palette.WHITE)

	_outline_image(img, Palette.OUTLINE)
	return ImageTexture.create_from_image(img)


## Two square rings sharing a middle edge — reads as an infinity symbol at
## small pixel sizes without needing a diagonal curve. Used by the mode-select
## screen for endless, the way cube() is used there for story.
static func infinity_icon(loop: int = 7) -> ImageTexture:
	var img := Image.create_empty(loop * 4 + 2, loop * 2 + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ox := 1
	var oy := 1

	for side in 2:
		var x0 := side * loop * 2
		for y in loop * 2:
			for x in loop * 2:
				var on_border := x == 0 or x == loop * 2 - 1 or y == 0 or y == loop * 2 - 1
				if not on_border:
					continue
				var shade := Palette.PURPLE if (x + y) % 3 != 0 else Palette.MAGENTA
				img.set_pixel(ox + x0 + x, oy + y, shade)

	img.set_pixel(ox + loop - 1, oy + 1, Palette.WHITE)
	img.set_pixel(ox + loop * 3, oy + 1, Palette.WHITE)

	_outline_image(img, Palette.OUTLINE)
	return ImageTexture.create_from_image(img)


## Wrap every opaque pixel with `color` on its empty orthogonal neighbours.
static func _outline_image(img: Image, color: Color) -> void:
	var todo: Array[Vector2i] = []
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a == 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, y) + d
				if n.x < 0 or n.y < 0 or n.x >= img.get_width() or n.y >= img.get_height():
					continue
				if img.get_pixel(n.x, n.y).a == 0.0:
					todo.append(n)
	for p in todo:
		img.set_pixel(p.x, p.y, color)
