extends Node

## Writes every campaign room to JSON so tools/verify_rooms.py can check the
## real thing instead of a hand-copied mirror of it. The mirror was the reason
## the checker silently stopped covering the campaign after room 12.
##
##   godot --headless --script-scene tools/dump_rooms.tscn
##
## Output: tools/rooms.json

func _ready() -> void:
	var out := []
	for room: Dictionary in Levels.all():
		out.append({
			"id": room.get("id", ""),
			"par": room.get("par", 0.0),
			"rows": Array(room["rows"] as PackedStringArray),
		})
	var f := FileAccess.open("res://tools/rooms.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("wrote %d rooms to tools/rooms.json" % out.size())
	get_tree().quit()
