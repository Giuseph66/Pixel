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
const DASH_ROOM := 12           # 0-based: room 13, "FIRST DASH"
const POUND_ROOM := 18          # room 19, "SLAM"

var settings := {
	"music": true,
	"sfx": true,
	"lang": "",             # empty means "guess from the system locale"
}

var slots: Array = []
var active := 0
var data: Dictionary = {}

var _since_write := 0.0


static func blank_slot() -> Dictionary:
	return {
		"used": false,          # false until the slot has been played at all
		"unlocked": 1,          # how many rooms are selectable
		"best_times": {},       # room index (as String) -> seconds
		"cleared": {},          # room index (as String) -> true
		"gems": {},             # room index (as String) -> best gem count
		"total_deaths": 0,
		"endless_best": 0,      # deepest endless run, in rooms cleared
		"endless_gems": 0,      # gems taken in that run
		"play_time": 0.0,
		"gems_taken": 0,        # every gem ever picked up, not the best per room
		"codex": {},            # entry id -> true, once seen
	}


func _ready() -> void:
	for i in SLOTS:
		slots.append(blank_slot())
	data = slots[0]
	load_game()


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

func is_unlocked(index: int) -> bool:
	return index < int(data["unlocked"])


func is_cleared(index: int) -> bool:
	return bool(data["cleared"].get(str(index), false))


func best_time(index: int) -> float:
	return float(data["best_times"].get(str(index), 0.0))


func best_gems(index: int) -> int:
	return int(data["gems"].get(str(index), 0))


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
	return is_unlocked(DASH_ROOM)


func can_pound() -> bool:
	return is_unlocked(POUND_ROOM)


# --------------------------------------------------------------- discovery ---

func knows(entry: String) -> bool:
	return bool(data["codex"].get(entry, false))


## Note that the player has met something. Returns true the first time, which
## is what the "new entry" flash on screen keys off.
func discover(entry: String) -> bool:
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
func record_clear(index: int, time: float, gems: int, level_count: int) -> bool:
	var key := str(index)
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

	save_game()
	return record


## Record a finished endless run. Returns true when it beat the old depth.
func record_endless(rooms: int, gems: int) -> bool:
	data["used"] = true
	var record := rooms > int(data["endless_best"])
	if record:
		data["endless_best"] = rooms
		data["endless_gems"] = gems
	save_game()
	return record


func add_death() -> void:
	data["total_deaths"] = int(data["total_deaths"]) + 1


func add_gem() -> void:
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
