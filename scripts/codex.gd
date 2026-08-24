class_name Codex
extends RefCounted

## The book. One entry per thing the game can do to you or for you, revealed
## the first time you meet it — an empty page is a promise, not a gap.
##
## Text lives in i18n under codex.<id>.name and codex.<id>.text; this file only
## says what exists, what kind it is, and which sprite stands for it.

const MOVE := "move"
const ENEMY := "enemy"
const WORLD := "world"

const ENTRIES := [
	{"id": "run", "kind": MOVE, "sprite": "player_run_a"},
	{"id": "jump", "kind": MOVE, "sprite": "player_jump"},
	{"id": "wall", "kind": MOVE, "sprite": "player_wall"},
	{"id": "stomp", "kind": MOVE, "sprite": "player_fall"},
	{"id": "dash", "kind": MOVE, "sprite": "player_jump"},
	{"id": "pound", "kind": MOVE, "sprite": "player_fall"},

	{"id": "slime", "kind": ENEMY, "sprite": "slime_a"},
	{"id": "bat", "kind": ENEMY, "sprite": "bat_a"},
	{"id": "saw", "kind": ENEMY, "sprite": "saw_a"},

	{"id": "gem", "kind": WORLD, "sprite": "gem"},
	{"id": "door", "kind": WORLD, "sprite": "door"},
	{"id": "spike", "kind": WORLD, "sprite": "spike"},
	{"id": "spring", "kind": WORLD, "sprite": "spring"},
	{"id": "crystal", "kind": WORLD, "sprite": "crystal"},
	{"id": "crumble", "kind": WORLD, "sprite": "crumble"},
	{"id": "timed", "kind": WORLD, "sprite": "timed_on"},
	{"id": "breakable", "kind": WORLD, "sprite": "breakable"},
	{"id": "platform", "kind": WORLD, "sprite": "platform_icon"},
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
}


static func count() -> int:
	return ENTRIES.size()


static func entry(id: String) -> Dictionary:
	for e: Dictionary in ENTRIES:
		if e["id"] == id:
			return e
	return {}
