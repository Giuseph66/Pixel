extends Node

## Autoload. Everything the game remembers, as JSON in user://saves.json.
##
## The file holds three independent runs plus the settings that sit above all
## of them. A slot is a whole playthrough: clearing it back to zero is how you
## replay the campaign with the abilities locked again, without throwing away
## what the other slots did.
##
## `data` always points at the active slot, so the rest of the game reads
## progress exactly the way it did when there was only one.

const PATH := "user://saves.json"
const LEGACY := "user://save.json"
const SLOTS := 3
const AUTOSAVE := 15.0          # seconds of play between disk writes

## Rooms whose unlock also hands over an ability. Story order is the teacher,
## so the move arrives with the room built to teach it.
const DASH_ROOM_ID := "first_dash"
const POUND_ROOM_ID := "slam"

var settings := {
	"music": true,
	"sfx": true,
	"lang": "",             # empty means "guess from the system locale"
}

var slots: Array = []
var active := 0
var data: Dictionary = {}

var _since_write := 0.0
## What the last finished room newly earned, for the results screen to read.
var last_awarded := 0

## Turned off while a sandbox room is running. A custom room is not part of any
## campaign, so nothing it does may reach the save file — and it must not, for
## a sharper reason than tidiness: rooms are keyed by their index in
## Levels.ids(), so a sandbox room at index 0 would file its record under
## FIRST STEPS and quietly overwrite a real one.
var tracking := true


## 1: rooms keyed by index. 2: rooms keyed by the stable id in levels.gd.
const SCHEMA := 2

const MEDAL_TIME := 1
const MEDAL_GEMS := 2
const MEDAL_CLEAN := 4

static func blank_slot() -> Dictionary:
	return {
		"used": false,          # false until the slot has been played at all
		"unlocked": 1,          # how many rooms are selectable
		"best_times": {},       # room index (as String) -> seconds
		"cleared": {},          # room index (as String) -> true
		"gems": {},             # room index (as String) -> best gem count
		"medals": {},           # room id -> bitmask (1=time, 2=gems, 4=clean)
		"secrets": {},          # room id -> true when its secret gem was taken
		"secrets_taken": 0,     # how many secret gems this slot has ever found
		"total_deaths": 0,
		# Step 20 — endless modifiers. Keyed by combo, "+"-joined and sorted
		# ("" for a plain run, "dark", "rush+dark"): a modified run is a
		# different challenge, not a harder version of the same one, so it
		# keeps its own record rather than competing with a clean run's.
		"endless_best": {},     # combo key -> deepest run, in rooms cleared
		"endless_gems": {},     # combo key -> gems taken in that run
		"play_time": 0.0,
		"gems_taken": 0,        # every gem ever picked up, not the best per room
		"codex": {},            # entry id -> true, once seen
		# Step 11 — the remix's own progress, kept apart from the campaign's so
		# a mirrored clear never counts toward cleared_count() and thus toward
		# unlocking the remix itself. Declared here rather than created on
		# first use because _read() only copies keys a blank slot already
		# names: absent from this dictionary, it is absent from every loaded
		# slot too, and every remix reader indexes it directly.
		"remix": {
			"best_times": {},   # room id -> seconds
			"cleared": {},      # room id -> true
			"gems": {},         # room id -> best gem count
			"medals": {},       # room id -> bitmask, same bits as the campaign
		},
		# Bumped when the key format changes. Two things depend on it living
		# here. _read() only copies keys a blank slot already declares, so a
		# marker missing from this dictionary would never survive a restart and
		# the migration would run again on data it had already converted. And
		# it starts at 1, not SCHEMA: a save written before the marker existed
		# has no marker to load, so the default it falls back to has to be the
		# old format, or the migration skips exactly the slots that need it.
		"schema": 1,
	}


func _ready() -> void:
	for i in SLOTS:
		slots.append(blank_slot())
	data = slots[0]
	load_game()
	# Warm the room-id cache now rather than on the first save query, which
	# would otherwise land inside the level select's first frame and hitch it.
	Levels.ids()


# ------------------------------------------------------------------- disk ---

func load_game() -> void:
	if FileAccess.file_exists(PATH):
		_read(PATH)
		return
	# A save from before slots existed becomes slot one, so nobody loses a run
	# to an update.
	if FileAccess.file_exists(LEGACY):
		_import_legacy()


func _read(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	if parsed.has("settings") and typeof(parsed["settings"]) == TYPE_DICTIONARY:
		for key in settings.keys():
			if parsed["settings"].has(key):
				settings[key] = parsed["settings"][key]

	if parsed.has("slots") and typeof(parsed["slots"]) == TYPE_ARRAY:
		var stored: Array = parsed["slots"]
		for i in mini(stored.size(), SLOTS):
			if typeof(stored[i]) != TYPE_DICTIONARY:
				continue
			var slot: Dictionary = slots[i]
			for key in slot.keys():
				if stored[i].has(key):
					slot[key] = stored[i][key]

	active = clampi(int(parsed.get("active", 0)), 0, SLOTS - 1)
	data = slots[active]

	for slot: Dictionary in slots:
		_migrate_to_schema_2(slot)
		_repair_remix(slot)
		_migrate_endless_best(slot)


func _import_legacy() -> void:
	var f := FileAccess.open(LEGACY, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var slot: Dictionary = slots[0]
	for key in slot.keys():
		if parsed.has(key):
			slot[key] = parsed[key]
	slot["used"] = true
	for key in settings.keys():
		if parsed.has(key):
			settings[key] = parsed[key]

	active = 0
	data = slots[0]
	save_game()


## Rooms used to be keyed by their index in Levels.all(), which meant inserting
## a room silently handed one player's records to another room. They are keyed
## by a stable id now; this rewrites an old slot once.
const SCHEMA_1_ORDER := [
	"first_steps", "prickly", "ceiling_spikes", "slime_time", "bounce",
	"the_climb", "double_trouble", "spring_stair", "ledge_climb", "spike_gauntlet",
	"spring_tower", "wall_finale", "first_dash", "crystal_chain", "platform_ride",
	"beat", "dash_gauntlet", "mid_finale", "slam", "break_in", "chain_bounce",
]


## _read() replaces a declared key with whatever the file held for it, so the
## well-formed default above survives only as long as the file agrees. Every
## remix reader indexes the four sub-dictionaries directly; this puts back any
## the file is missing rather than letting the mode raise on the first read.
## Saves written before the remix existed have no "remix" at all and land here
## with the blank default already in place, which is exactly right.
func _repair_remix(slot: Dictionary) -> void:
	if typeof(slot.get("remix")) != TYPE_DICTIONARY:
		slot["remix"] = blank_slot()["remix"]
		return
	var remix: Dictionary = slot["remix"]
	for field: String in ["best_times", "cleared", "gems", "medals"]:
		if typeof(remix.get(field)) != TYPE_DICTIONARY:
			remix[field] = {}


## endless_best/endless_gems used to be one scalar for the whole slot. A save
## written before step 20 has them as a plain int; the modifier-keyed run
## folds forward as the "" (no modifier) combo, so nobody's depth record
## disappears the first time this loads.
func _migrate_endless_best(slot: Dictionary) -> void:
	if typeof(slot.get("endless_best")) == TYPE_DICTIONARY:
		return
	var old_best := int(slot.get("endless_best", 0))
	var old_gems := int(slot.get("endless_gems", 0))
	slot["endless_best"] = {"": old_best} if old_best > 0 else {}
	slot["endless_gems"] = {"": old_gems} if old_gems > 0 else {}


func _migrate_to_schema_2(slot: Dictionary) -> void:
	if int(slot.get("schema", 1)) >= 2:
		return

	for field: String in ["best_times", "cleared", "gems"]:
		var old_values: Dictionary = slot.get(field, {})
		var moved := {}
		for i in SCHEMA_1_ORDER.size():
			var old_key := str(i)
			if old_values.has(old_key):
				moved[SCHEMA_1_ORDER[i]] = old_values[old_key]
		# Anything already keyed by id is kept as it is: a half-migrated slot
		# must never lose the half that was already done.
		for key: String in old_values:
			if not key.is_valid_int():
				moved[key] = old_values[key]
		slot[field] = moved

	slot["schema"] = SCHEMA


func save_game() -> void:
	_since_write = 0.0
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"settings": settings,
		"slots": slots,
		"active": active,
	}, "\t"))
	f.close()


# ------------------------------------------------------------------ slots ---

func use_slot(index: int) -> void:
	active = clampi(index, 0, SLOTS - 1)
	data = slots[active]
	save_game()


## Clear one slot back to a fresh campaign. The other slots are untouched, so
## this is "start over", never "lose everything".
func reset_slot(index: int) -> void:
	if index < 0 or index >= SLOTS:
		return
	slots[index] = blank_slot()
	if index == active:
		data = slots[index]
	save_game()


func slot_is_empty(index: int) -> bool:
	return not bool((slots[index] as Dictionary)["used"])


# ---------------------------------------------------------------- queries ---

## The save key for a room. Endless rooms are not in the campaign list and fall
## back to the index, which is all they ever need.
func _key(index: int) -> String:
	var list := Levels.ids()
	if index < 0 or index >= list.size() or list[index].is_empty():
		return str(index)
	return list[index]


func is_unlocked(index: int) -> bool:
	return index < int(data["unlocked"])


func is_cleared(index: int) -> bool:
	return bool(data["cleared"].get(_key(index), false))


func best_time(index: int) -> float:
	return float(data["best_times"].get(_key(index), 0.0))

   
func best_gems(index: int) -> int:
	return int(data["gems"].get(_key(index), 0))


func medals(index: int) -> int:
	return int(data["medals"].get(_key(index), 0))


func total_gems() -> int:
	var sum := 0
	for v in data["gems"].values():
		sum += int(v)
	return sum


func cleared_count() -> int:
	return data["cleared"].size()


## Abilities ride on room unlocks: reach the room that teaches the move and you
## have the move, in that room and every other one.
func can_dash() -> bool:
	var dash_index := Levels.index_of(DASH_ROOM_ID)
	return dash_index >= 0 and is_unlocked(dash_index)


func can_pound() -> bool:
	var pound_index := Levels.index_of(POUND_ROOM_ID)
	return pound_index >= 0 and is_unlocked(pound_index)


# ------------------------------------------------------------------ remix ---

## Every room mirrored and sped up, open once the campaign is finished. It has
## its own progress, entirely separate from the campaign's.
func remix_unlocked() -> bool:
	return cleared_count() >= Levels.count()


func is_cleared_remix(index: int) -> bool:
	return bool(data["remix"]["cleared"].get(_key(index), false))


func best_time_remix(index: int) -> float:
	return float(data["remix"]["best_times"].get(_key(index), 0.0))


func best_gems_remix(index: int) -> int:
	return int(data["remix"]["gems"].get(_key(index), 0))


func medals_remix(index: int) -> int:
	return int(data["remix"]["medals"].get(_key(index), 0))


## Same shape as record_clear(), on the remix namespace. There is no unlock
## counter to advance here — every remix room is open the moment the mode is.
func record_clear_remix(index: int, time: float, gems: int, total_gems: int,
		deaths: int, par: float) -> bool:
	if not tracking:
		return false
	var key := _key(index)
	var remix: Dictionary = data["remix"]
	var record := false

	data["used"] = true
	remix["cleared"][key] = true
	var previous := best_time_remix(index)
	if previous <= 0.0 or time < previous:
		remix["best_times"][key] = time
		record = previous > 0.0
	if gems > best_gems_remix(index):
		remix["gems"][key] = gems

	var earned := 0
	if par > 0.0 and time <= par:
		earned |= MEDAL_TIME
	if total_gems > 0 and gems >= total_gems:
		earned |= MEDAL_GEMS
	if deaths == 0:
		earned |= MEDAL_CLEAN
	# Read what was held BEFORE writing the union back, the way _award() does.
	# Reading it again afterwards asks "what is new" of a set that already
	# contains everything this attempt won, which is always nothing — and a
	# first medal never got its flash on the results screen because of it.
	var before := medals_remix(index)
	remix["medals"][key] = before | earned
	last_awarded = earned & ~before

	save_game()
	return record


# --------------------------------------------------------------- discovery ---

func knows(entry: String) -> bool:
	return bool(data["codex"].get(entry, false))


## Note that the player has met something. Returns true the first time, which
## is what the "new entry" flash on screen keys off.
func discover(entry: String) -> bool:
	if not tracking:
		return false
	if knows(entry):
		return false
	data["codex"][entry] = true
	data["used"] = true
	save_game()
	return true


func known_count() -> int:
	return data["codex"].size()


# ---------------------------------------------------------------- updates ---

## Record a finished room. Returns true when the time was a new record.
func record_clear(index: int, time: float, gems: int, level_count: int,
		total_gems: int, deaths: int, par: float) -> bool:
	if not tracking:
		return false
	var key := _key(index)
	var record := false

	data["used"] = true
	data["cleared"][key] = true
	var previous := best_time(index)
	if previous <= 0.0 or time < previous:
		data["best_times"][key] = time
		record = previous > 0.0
	if gems > best_gems(index):
		data["gems"][key] = gems
	if index + 1 >= int(data["unlocked"]) and index + 1 < level_count:
		data["unlocked"] = index + 2

	last_awarded = _award(index, time, gems, total_gems, deaths, par)
	save_game()
	return record


## Hand out whatever this attempt earned and report back only what is new, so
## the results screen can celebrate a first medal without re-celebrating three
## the player already had. Medals accumulate: a slow clean run and a fast messy
## one add up to two medals over two visits.
func _award(index: int, time: float, gems: int, total: int, deaths: int, par: float) -> int:
	var earned := 0
	if par > 0.0 and time <= par:
		earned |= MEDAL_TIME
	if total > 0 and gems >= total:
		earned |= MEDAL_GEMS
	if deaths == 0:
		earned |= MEDAL_CLEAN
	var before := medals(index)
	data["medals"][_key(index)] = before | earned
	return earned & ~before


## Every medal in the campaign, for the counter on the front end.
func medal_count() -> int:
	var total := 0
	for value in data["medals"].values():
		var bits := int(value)
		total += (bits & 1) + ((bits >> 1) & 1) + ((bits >> 2) & 1)
	return total


func has_secret(index: int) -> bool:
	return bool(data["secrets"].get(_key(index), false))


## Secret gems keep their own tally. Folding them into gems_taken would make
## the lifetime gem count mean two different things at once.
func take_secret(index: int) -> void:
	if not tracking:
		return
	if has_secret(index):
		return
	data["secrets"][_key(index)] = true
	data["secrets_taken"] = int(data.get("secrets_taken", 0)) + 1


func secret_count() -> int:
	return int(data.get("secrets_taken", 0))


## Record a finished endless run against its own modifier combo. Returns true
## when it beat the old depth for that combo specifically — "" is the plain,
## no-modifier run.
func record_endless(rooms: int, gems: int, mods_key: String = "") -> bool:
	if not tracking:
		return false
	data["used"] = true
	var best: Dictionary = data["endless_best"]
	var record := rooms > int(best.get(mods_key, 0))
	if record:
		best[mods_key] = rooms
		(data["endless_gems"] as Dictionary)[mods_key] = gems
	save_game()
	return record


func endless_best(mods_key: String = "") -> int:
	return int((data["endless_best"] as Dictionary).get(mods_key, 0))


func endless_gems(mods_key: String = "") -> int:
	return int((data["endless_gems"] as Dictionary).get(mods_key, 0))


## The deepest run across every combo, for a summary screen with no room to
## break the record down by combo.
static func best_of(dict: Dictionary) -> int:
	var best := 0
	for v in dict.values():
		best = maxi(best, int(v))
	return best


## Score and best combo are their own record, independent of depth: a shallow
## run played with style can beat a deep run played flat, and the two numbers
## should not have to agree to both be worth keeping.
func record_endless_score(run_score: int, run_best_combo: int) -> bool:
	if not tracking:
		return false
	data["used"] = true
	var record := run_score > int(data.get("endless_score", 0))
	if record:
		data["endless_score"] = run_score
	if run_best_combo > int(data.get("endless_best_combo", 0)):
		data["endless_best_combo"] = run_best_combo
	save_game()
	return record


func add_death() -> void:
	if not tracking:
		return
	data["total_deaths"] = int(data["total_deaths"]) + 1


func add_gem() -> void:
	if not tracking:
		return
	data["gems_taken"] = int(data["gems_taken"]) + 1


## Called every frame while the game is running. Writing to disk on every one
## of those would be absurd, so it batches.
func add_play_time(delta: float) -> void:
	data["play_time"] = float(data["play_time"]) + delta
	_since_write += delta
	if _since_write >= AUTOSAVE:
		save_game()


func set_music(on: bool) -> void:
	settings["music"] = on
	save_game()


func set_sfx(on: bool) -> void:
	settings["sfx"] = on
	save_game()


func set_lang(code: String) -> void:
	settings["lang"] = code
	save_game()
