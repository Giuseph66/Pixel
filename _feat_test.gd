extends Node2D

func _ready() -> void:
	var levels := Levels.all()
	print("story rooms: ", levels.size())
	var problems := 0

	for i in levels.size():
		var data: Dictionary = levels[i]
		var rows: PackedStringArray = data["rows"]
		var j := ""
		for r in rows:
			j += r
			if r.length() != Levels.COLS:
				print("BAD WIDTH room ", i + 1)
				problems += 1
		for ch in ["P", "X"]:
			if j.count(ch) != 1:
				print("BAD ", ch, " in room ", i + 1)
				problems += 1
		if j.count("o") < 1:
			print("NO GEMS room ", i + 1)
			problems += 1
		# Any hole in the floor has to end in spikes, or a fall is a soft lock.
		for x in Levels.COLS:
			var solid := false
			for y in range(27, Levels.ROWS):
				if rows[y][x] in ["#", "^"]:
					solid = true
					break
			if not solid:
				print("BOTTOMLESS col ", x, " room ", i + 1)
				problems += 1
		if Lang.t(data["name"]) == data["name"]:
			print("UNTRANSLATED ", data["name"])
			problems += 1
		if Lang.t(data["hint"]) == data["hint"]:
			print("UNTRANSLATED ", data["hint"])
			problems += 1

	print("STORY PROBLEMS ", problems)

	# The six new rooms must actually build and populate.
	for i in [12, 13, 14, 15, 16, 17]:
		var level := Level.new()
		level.setup(i, levels[i])
		add_child(level)
		for f in 6:
			await get_tree().physics_frame
		var kinds := {}
		for child in _all(level):
			if child.get_script() != null:
				var k: String = str(child.get_script().resource_path.get_file())
				kinds[k] = int(kinds.get(k, 0)) + 1
		print("room %2d gems=%d %s" % [i + 1, level.gems_total, str(kinds)])
		level.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _all(node: Node) -> Array:
	var out := []
	for child in node.get_children():
		out.append(child)
		out.append_array(_all(child))
	return out
