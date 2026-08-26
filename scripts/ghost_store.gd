class_name GhostStore
extends RefCounted

## Step 25 — personal-best ghost, on disk. One binary file per (slot, room),
## never a blob inside saves.json: a 90s run at 20Hz is ~7KB, and saves.json
## is rewritten whole on every write already triggered mid-room by
## Save.discover() — adding this there would mean serialising hundreds of KB
## in the middle of a room least able to afford the hitch.
##
## Positions are stored as unsigned 16-bit pairs. A room is 480x256px, so
## nothing here ever needs the sign bit or more than two bytes a side.

const DIR := "user://ghosts"
const SAMPLE_HZ := 20
const MAGIC := 0x47535431        # "GST1"
const MAX_SAMPLES := 1800        # 90s cap; a longer run does not get a ghost


static func _path(slot: int, room_id: String, remix: bool) -> String:
	var prefix := "r" if remix else str(slot)
	return "%s/%s_%s.gst" % [DIR, prefix, room_id]


## Silently does nothing for an empty id or an empty run — a ghost with no
## room to attach to, or no samples to play back, is not worth a file.
##
## `pounds` is a list of sample indices, not one more per-sample field: a
## ground pound is a single event, not a state every sample needs to carry,
## and only ever a handful happen in one run.
static func save(slot: int, room_id: String, remix: bool, samples: PackedVector2Array,
		pounds: PackedInt32Array = PackedInt32Array()) -> void:
	if room_id.is_empty() or samples.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var capped := samples
	if capped.size() > MAX_SAMPLES:
		capped = capped.slice(0, MAX_SAMPLES)
	var f := FileAccess.open(_path(slot, room_id, remix), FileAccess.WRITE)
	if f == null:
		return
	f.store_32(MAGIC)
	f.store_16(capped.size())
	for p: Vector2 in capped:
		f.store_16(clampi(roundi(p.x), 0, 65535))
		f.store_16(clampi(roundi(p.y), 0, 65535))
	# A pound past the sample cap has nothing left to land on; drop it rather
	# than write an index the read side would have to bounds-check forever.
	var kept := PackedInt32Array()
	for idx in pounds:
		if idx < capped.size():
			kept.append(idx)
	f.store_16(kept.size())
	for idx in kept:
		f.store_16(idx)
	f.close()


## Never lets a broken or foreign-version file block the room from opening —
## a bad ghost is deleted and treated as if it never existed.
##
## Returns {"samples": PackedVector2Array, "pounds": PackedInt32Array}. A file
## written before pounds existed simply ends after its samples — the section
## below never runs long enough to read anything, so it comes back empty
## rather than needing a format version to tell the two apart.
static func load(slot: int, room_id: String, remix: bool) -> Dictionary:
	var samples := PackedVector2Array()
	var pounds := PackedInt32Array()
	if room_id.is_empty():
		return {"samples": samples, "pounds": pounds}
	var path := _path(slot, room_id, remix)
	if not FileAccess.file_exists(path):
		return {"samples": samples, "pounds": pounds}

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"samples": samples, "pounds": pounds}
	if f.get_32() != MAGIC:
		f.close()
		DirAccess.remove_absolute(path)
		return {"samples": samples, "pounds": pounds}
	var count := f.get_16()
	for i in count:
		if f.get_position() + 4 > f.get_length():
			break
		var x := f.get_16()
		var y := f.get_16()
		samples.append(Vector2(float(x), float(y)))
	if f.get_position() + 2 <= f.get_length():
		var pound_count := f.get_16()
		for i in pound_count:
			if f.get_position() + 2 > f.get_length():
				break
			pounds.append(f.get_16())
	f.close()
	return {"samples": samples, "pounds": pounds}


## The only place a ghost is deleted outside of a bad read — reset_slot()
## calls this so starting a campaign over does not leave old ghosts playing
## alongside a save that no longer remembers setting the records they trace.
static func delete_all(slot: int) -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	var prefix := "%d_" % slot
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.begins_with(prefix) and name.ends_with(".gst"):
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
