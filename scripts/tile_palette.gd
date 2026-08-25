class_name TilePalette
extends RefCounted

## The editor's side of the tile alphabet.
##
## level.gd already knows what every character *does*; this file is the only
## place that says what a character is *called*, what it looks like in a
## palette and which drawer it lives in. Adding a mechanic means one entry
## here and the editor picks it up — no screen has a list of tiles in it.
##
## `sprite` is a key into PixelArt.GRIDS, drawn centred in the cell. When it is
## empty the tile is terrain and gets painted by the same routine the real room
## uses, so what the editor shows is what the room bakes.

const TERRAIN := "terrain"
const HAZARD := "hazard"
const CREATURE := "creature"
const ITEM := "item"
const MARKER := "marker"

## Drawer order in the palette popup. Each: id, name key, accent colour.
const GROUPS := [
	{"id": TERRAIN, "label": "pal.group.terrain", "color": Palette.CYAN},
	{"id": HAZARD, "label": "pal.group.hazard", "color": Palette.MAGENTA},
	{"id": CREATURE, "label": "pal.group.creature", "color": Palette.GREEN},
	{"id": ITEM, "label": "pal.group.item", "color": Palette.GOLD},
	{"id": MARKER, "label": "pal.group.marker", "color": Palette.PURPLE},
]

## One entry per paintable character.
##
##   char   what lands in the row string
##   group  which drawer it sits in
##   sprite PixelArt grid name, or "" for terrain painted in place
##   unique true when a room may only ever hold one of them
##   run    true when a horizontal row of them behaves as a single object,
##          which is the editor's excuse to say "drag me sideways"
const ENTRIES := [
	{"char": ".", "group": TERRAIN, "sprite": "", "unique": false, "run": false},
	{"char": "#", "group": TERRAIN, "sprite": "", "unique": false, "run": false},
	{"char": "~", "group": TERRAIN, "sprite": "ice", "unique": false, "run": false},
	{"char": "-", "group": TERRAIN, "sprite": "", "unique": false, "run": false},
	{"char": ">", "group": TERRAIN, "sprite": "belt_0", "unique": false, "run": true},
	{"char": "<", "group": TERRAIN, "sprite": "belt_2", "unique": false, "run": true},
	{"char": "c", "group": TERRAIN, "sprite": "crumble", "unique": false, "run": false},
	{"char": "k", "group": TERRAIN, "sprite": "breakable", "unique": false, "run": false},
	{"char": "t", "group": TERRAIN, "sprite": "timed_on", "unique": false, "run": false},
	{"char": "T", "group": TERRAIN, "sprite": "timed_off", "unique": false, "run": false},
	{"char": "m", "group": TERRAIN, "sprite": "platform_icon", "unique": false, "run": true},
	{"char": "n", "group": TERRAIN, "sprite": "platform_icon", "unique": false, "run": true},
	{"char": "r", "group": TERRAIN, "sprite": "platform_icon", "unique": false, "run": true},

	{"char": "^", "group": HAZARD, "sprite": "spike", "unique": false, "run": false},
	{"char": "v", "group": HAZARD, "sprite": "spike", "unique": false, "run": false},
	{"char": "z", "group": HAZARD, "sprite": "spike_up", "unique": false, "run": false},
	{"char": "Z", "group": HAZARD, "sprite": "spike_up", "unique": false, "run": false},
	{"char": "A", "group": HAZARD, "sprite": "", "unique": true, "run": false},

	{"char": "S", "group": CREATURE, "sprite": "slime_a", "unique": false, "run": false},
	{"char": "B", "group": CREATURE, "sprite": "bat_a", "unique": false, "run": false},
	{"char": "W", "group": CREATURE, "sprite": "saw_a", "unique": false, "run": false},
	{"char": "e", "group": CREATURE, "sprite": "elastic_a", "unique": false, "run": false},
	{"char": "E", "group": CREATURE, "sprite": "shield_a", "unique": false, "run": false},

	{"char": "o", "group": ITEM, "sprite": "gem", "unique": false, "run": false},
	{"char": "O", "group": ITEM, "sprite": "gem_secret", "unique": false, "run": false},
	{"char": "d", "group": ITEM, "sprite": "crystal", "unique": false, "run": false},
	{"char": "J", "group": ITEM, "sprite": "spring", "unique": false, "run": false},

	{"char": "P", "group": MARKER, "sprite": "player_idle", "unique": true, "run": false},
	{"char": "X", "group": MARKER, "sprite": "icon_door", "unique": true, "run": false},

	{"char": "i", "group": TERRAIN, "sprite": "switch_off", "unique": false, "run": false},
	{"char": "g", "group": TERRAIN, "sprite": "gate_solid", "unique": false, "run": false},
	{"char": "G", "group": TERRAIN, "sprite": "gate_open", "unique": false, "run": false},
	{"char": "u", "group": TERRAIN, "sprite": "wind_up", "unique": false, "run": true},
	{"char": "U", "group": TERRAIN, "sprite": "wind_side", "unique": false, "run": true},
	{"char": "p", "group": TERRAIN, "sprite": "phase_block", "unique": false, "run": false},
]

## Character -> i18n suffix. The name and the one-line note under the palette
## both hang off it: pal.<key>.name and pal.<key>.note.
const KEYS := {
	".": "air", "#": "solid", "~": "ice", "-": "oneway",
	">": "belt_right", "<": "belt_left", "c": "crumble", "k": "breakable",
	"t": "timed_on", "T": "timed_off", "m": "plat_h", "n": "plat_v", "r": "plat_orbit",
	"^": "spike_up", "v": "spike_down", "z": "retract_down", "Z": "retract_up",
	"A": "lava",
	"S": "slime", "B": "bat", "W": "saw", "e": "elastic", "E": "shield",
	"o": "gem", "O": "secret", "d": "crystal", "J": "spring",
	"P": "spawn", "X": "exit",
	"i": "switch", "g": "gate_solid", "G": "gate_open",
	"u": "wind_up", "U": "wind_side",
	"p": "phase",
}

## Painted over the icon where two tiles share a sprite. Three of the moving
## platforms are the same slab and only differ in the path they take, so the
## path is what the marker draws: a double arrow for the axis it rides, a ring
## for the one that orbits. Belts get a single arrow for the way they push.
const MARKS := {
	">": ["...x.", "xxxxx", "...x."],
	"<": [".x...", "xxxxx", ".x..."],
	"m": [".x...x.", "xxxxxxx", ".x...x."],
	"n": [".x.", "xxx", ".x.", ".x.", ".x.", "xxx", ".x."],
	"r": [".xxx.", "x...x", "x...x", "x...x", ".xxx."],
	# The retracting pair share one blade and differ only in the beat they
	# start on: 'z' flat, 'Z' already up.
	"z": ["x...x", ".xxx.", "..x.."],
	"Z": ["..x..", ".xxx.", "x...x"],
}

static var _by_char: Dictionary = {}


static func entry(ch: String) -> Dictionary:
	if _by_char.is_empty():
		for e: Dictionary in ENTRIES:
			_by_char[e["char"]] = e
	return _by_char.get(ch, {})


static func exists(ch: String) -> bool:
	return not entry(ch).is_empty()


static func is_unique(ch: String) -> bool:
	return bool(entry(ch).get("unique", false))


static func name_of(ch: String) -> String:
	return Lang.t("pal.%s.name" % KEYS.get(ch, "air"))


static func note_of(ch: String) -> String:
	return Lang.t("pal.%s.note" % KEYS.get(ch, "air"))


static func group_of(ch: String) -> String:
	return str(entry(ch).get("group", TERRAIN))


## Every character in one drawer, in the order written above.
static func in_group(group: String) -> Array:
	var out: Array = []
	for e: Dictionary in ENTRIES:
		if e["group"] == group:
			out.append(e)
	return out


static func group_color(group: String) -> Color:
	for g: Dictionary in GROUPS:
		if g["id"] == group:
			return g["color"]
	return Palette.GREY


## Flat list of characters, palette order. What the mouse wheel steps through.
static func mark_of(ch: String) -> Array:
	return MARKS.get(ch, [])


## The 8x8 picture of a tile, cached. Terrain is painted by the same routines
## the room bakes with — a lone tile with no neighbours, so every edge is lit —
## which is what keeps the palette and the room from disagreeing about what
## ground looks like. Everything else is its own sprite.
##
## Air has no picture; the editor draws its own placeholder for it.
static func icon(ch: String) -> ImageTexture:
	var key := "pal_icon_" + ch
	if PixelArt.has_cached(key):
		return PixelArt.cached(key)

	var sprite := str(entry(ch).get("sprite", ""))
	if not sprite.is_empty() and ch != "~":
		return PixelArt.store(key, PixelArt.tex(sprite))

	var img := Image.create_empty(PixelArt.TILE, PixelArt.TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match ch:
		"#":
			PixelArt.paint_tile(img, 0, 0, false, false, false, false)
		"~":
			PixelArt.paint_ice(img, 0, 0, false, false, false, false)
		"-":
			PixelArt.paint_platform(img, 0, 0)
		"A":
			# The tide is a level rather than a tile: a bright surface line
			# with the flood under it.
			for x in PixelArt.TILE:
				img.set_pixel(x, 0, Palette.MAGENTA)
				img.set_pixel(x, 1, Palette.MAGENTA)
			for y in range(2, PixelArt.TILE):
				for x in PixelArt.TILE:
					img.set_pixel(x, y, Palette.MAGENTA_DARK)
	return PixelArt.store(key, ImageTexture.create_from_image(img))


static func chars() -> PackedStringArray:
	var out := PackedStringArray()
	for e: Dictionary in ENTRIES:
		out.append(e["char"])
	return out
