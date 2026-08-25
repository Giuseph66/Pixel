class_name Codex
extends RefCounted

## The book. One entry per thing the game can do to you or for you, revealed
## the first time you meet it — an empty page is a promise, not a gap.
##
## Text lives in i18n under codex.<id>.name and codex.<id>.text; this file only
## says what exists, which chapter it belongs to, and which sprite stands for
## it. CodexScreen reads CHAPTERS to lay the book out — one chapter per tab,
## entries kept in the order they are written here.

const ABILITY := "ability"
const CREATURE := "creature"
const COLLECTIBLE := "collectible"
const WORLD := "world"

## Tab order, top to bottom. Each entry: kind id, name key, accent colour.
const CHAPTERS := [
	{"kind": ABILITY, "label": "codex.cat.ability", "color": Palette.CYAN},
	{"kind": CREATURE, "label": "codex.cat.creature", "color": Palette.GREEN},
	{"kind": COLLECTIBLE, "label": "codex.cat.collectible", "color": Palette.GOLD},
	{"kind": WORLD, "label": "codex.cat.world", "color": Palette.PURPLE},
]

const ENTRIES := [
	# Abilities use pictograms, not player poses. The game only has a handful of
	# player sprites, so run/jump/wall/stomp all resolved to near-identical
	# little figures and the chapter looked like one entry repeated six times.
	{"id": "run", "kind": ABILITY, "sprite": "icon_run"},
	{"id": "jump", "kind": ABILITY, "sprite": "icon_jump"},
	{"id": "wall", "kind": ABILITY, "sprite": "icon_wall"},
	{"id": "stomp", "kind": ABILITY, "sprite": "icon_stomp"},
	{"id": "dash", "kind": ABILITY, "sprite": "icon_dash"},
	{"id": "pound", "kind": ABILITY, "sprite": "icon_pound"},
	{"id": "combo", "kind": ABILITY, "sprite": "icon_combo"},

	{"id": "slime", "kind": CREATURE, "sprite": "slime_a"},
	{"id": "bat", "kind": CREATURE, "sprite": "bat_a"},
	{"id": "saw", "kind": CREATURE, "sprite": "saw_a"},

	{"id": "gem", "kind": COLLECTIBLE, "sprite": "gem"},
	{"id": "crystal", "kind": COLLECTIBLE, "sprite": "crystal"},

	{"id": "door", "kind": WORLD, "sprite": "icon_door"},
	{"id": "spike", "kind": WORLD, "sprite": "spike"},
	{"id": "spring", "kind": WORLD, "sprite": "spring"},
	{"id": "crumble", "kind": WORLD, "sprite": "crumble"},
	{"id": "timed", "kind": WORLD, "sprite": "timed_on"},
	{"id": "breakable", "kind": WORLD, "sprite": "breakable"},
	{"id": "platform", "kind": WORLD, "sprite": "platform_icon"},
	{"id": "ice", "kind": WORLD, "sprite": "ice"},
	{"id": "belt", "kind": WORLD, "sprite": "belt_0"},
	{"id": "retract", "kind": WORLD, "sprite": "spike_up"},
	{"id": "orbit", "kind": WORLD, "sprite": "platform_icon"},
	{"id": "lava", "kind": WORLD, "sprite": "spike_up"},
	{"id": "elastic", "kind": CREATURE, "sprite": "elastic_a"},
	{"id": "shield", "kind": CREATURE, "sprite": "shield_a"},
	{"id": "secret", "kind": COLLECTIBLE, "sprite": "gem_secret"},
	{"id": "switch", "kind": WORLD, "sprite": "switch_off"},
	{"id": "wind", "kind": WORLD, "sprite": "wind_up"},
	{"id": "phase", "kind": WORLD, "sprite": "phase_block"},
	{"id": "portal", "kind": WORLD, "sprite": "portal_a"},
]

## Which entry a level tile reveals, for the pass that runs when a room builds.
const BY_TILE := {
	"o": "gem",
	"X": "door",
	"^": "spike",
	"v": "spike",
	"J": "spring",
	"S": "slime",
	"B": "bat",
	"W": "saw",
	"c": "crumble",
	"t": "timed",
	"T": "timed",
	"k": "breakable",
	"d": "crystal",
	"m": "platform",
	"n": "platform",
	"~": "ice",
	">": "belt",
	"<": "belt",
	"z": "retract",
	"Z": "retract",
	"r": "orbit",
	"e": "elastic",
	"E": "shield",
	"A": "lava",
	"O": "secret",
	"i": "switch",
	"g": "switch",
	"G": "switch",
	"u": "wind",
	"U": "wind",
	"p": "phase",
	"q": "portal",
	"Q": "portal",
}


static func count() -> int:
	return ENTRIES.size()


static func entry(id: String) -> Dictionary:
	for e: Dictionary in ENTRIES:
		if e["id"] == id:
			return e
	return {}


## Every entry belonging to one chapter, in book order.
static func in_chapter(kind: String) -> Array:
	var out: Array = []
	for e: Dictionary in ENTRIES:
		if e["kind"] == kind:
			out.append(e)
	return out


static func chapter_index(kind: String) -> int:
	for i in CHAPTERS.size():
		if CHAPTERS[i]["kind"] == kind:
			return i
	return 0
