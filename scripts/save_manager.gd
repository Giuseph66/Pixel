extends Node

## Autoload. Progress and settings, stored as JSON in user://save.json.

const PATH := "user://save.json"

var data := {
	"unlocked": 1,          # how many levels are selectable
	"best_times": {},       # level index (as String) -> seconds
	"cleared": {},          # level index (as String) -> true
	"gems": {},             # level index (as String) -> best gem count
	"total_deaths": 0,
	"music": true,
	"sfx": true,
	"lang": "",             # empty means "guess from the system locale"
}


func _ready() -> void:
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for key in data.keys():
		if parsed.has(key):
			data[key] = parsed[key]


func save_game() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


# --------------------------------------------------------------- queries ---

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


# --------------------------------------------------------------- updates ---

## Record a finished level. Returns true when the time was a new record.
func record_clear(index: int, time: float, gems: int, level_count: int) -> bool:
	var key := str(index)
	var record := false

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


func add_death() -> void:
	data["total_deaths"] = int(data["total_deaths"]) + 1


func set_music(on: bool) -> void:
	data["music"] = on
	save_game()


func set_sfx(on: bool) -> void:
	data["sfx"] = on
	save_game()


func set_lang(code: String) -> void:
	data["lang"] = code
	save_game()


func wipe() -> void:
	data = {
		"unlocked": 1,
		"best_times": {},
		"cleared": {},
		"gems": {},
		"total_deaths": 0,
		"music": bool(data["music"]),
		"sfx": bool(data["sfx"]),
		"lang": str(data["lang"]),
	}
	save_game()
