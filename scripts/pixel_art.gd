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
}

static var _cache: Dictionary = {}


## Texture for a named grid, built once and reused.
static func tex(name: String) -> ImageTexture:
	if _cache.has(name):
		return _cache[name]
	var t := from_grid(GRIDS[name])
	_cache[name] = t
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


## One-way platform: a thin lit slab you can jump up through.
static func paint_platform(img: Image, tx: int, ty: int) -> void:
	var ox := tx * TILE
	var oy := ty * TILE
	for x in TILE:
		img.set_pixel(ox + x, oy, Palette.CYAN_MID)
		img.set_pixel(ox + x, oy + 1, Palette.CYAN_DARK)
		img.set_pixel(ox + x, oy + 2, Palette.OUTLINE)


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
