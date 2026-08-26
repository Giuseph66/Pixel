class_name Sandbox
extends RefCounted

## Rooms the player made, and everything that moves them between machines.
##
## A sandbox room is the same dictionary shape a campaign room is — name, hint,
## par, rows — plus the handful of knobs the editor exposes. That is the whole
## trick behind this mode: Level.setup() cannot tell a hand-painted room from
## one levels.gd built, so playing a custom room needs no new gameplay code.
##
## Three places rooms can live:
##   user://sandbox.json   the player's own rooms, edited in the editor
##   user://rooms/         drop-in files a friend sent, imported on request
##   res://rooms/          shipped extras, appended to the campaign at boot
##
## The share format is plain readable JSON, so a room can be mailed, pasted
## into a message or committed to the repo without any tooling.

const STORE := "user://sandbox.json"
const DROP_DIR := "user://rooms"
## Where exports go when the system has no downloads folder to put them in.
const EXPORT_FALLBACK := "user://export"
const PACK_DIR := "res://rooms"
const EXT := "pixelroom"

const FORMAT := "pixel.room"
const FORMAT_PACK := "pixel.pack"
const VERSION := 1

## Share codes are the same JSON, deflated and base64'd, behind a prefix that
## makes a stray paste obvious instead of mysterious.
const CODE_PREFIX := "PIXEL1."
const CODE_LIMIT := 262144

const MAX_ROOMS := 64
const NAME_LIMIT := 22

static var _rooms: Array = []
static var _loaded := false
static var _pack: Array = []
static var _pack_loaded := false


# ------------------------------------------------------------------ model ---

## A fresh room: sealed box, a floor, a spawn and a door. Never an empty grid —
## an empty grid is a puzzle about the editor rather than about the game.
static func blank_room() -> Dictionary:
	var g := Levels.blank()
	Levels.rect(g, 0, 27, Levels.COLS, 5, "#")
	Levels.put(g, 4, 26, "P")
	Levels.put(g, 53, 26, "X")
	return {
		"id": new_id(),
		"name": Lang.t("sandbox.untitled"),
		"hint": "",
		"par": 30.0,
		"intensity": 1.0,
		"dash": true,
		"pound": true,
		"seed": randi() % 100000,
		"author": "",
		"rows": Levels.bake(g),
		# Plain dots, not Levels.blank(): that seals a border of '#' for the
		# main grid's walls, which a backdrop grid has no use for and would
		# otherwise read as a no-dash/no-pound zone around the whole room.
		"backdrop_gravity": _pad_grid([]),
		"backdrop_no_dash": _pad_grid([]),
		"backdrop_no_pound": _pad_grid([]),
	}


static func new_id() -> String:
	return "sbx_%08x" % (randi() & 0x7fffffff)


## Fill in anything a room is missing, so a file written by an older build — or
## by hand — still loads. Rows are the one field with no sensible default.
## A short or ragged grid is padded rather than rejected: half a room is
## still worth opening in the editor. Shared by "rows" and the Fundo backdrop
## grids, which are the same shape and miss the same way in an old save.
static func _pad_grid(raw) -> PackedStringArray:
	var rows := PackedStringArray()
	if raw is PackedStringArray:
		rows = raw
	elif raw is Array:
		for line in raw:
			rows.append(str(line))

	while rows.size() < Levels.ROWS:
		rows.append("".lpad(Levels.COLS, "."))
	rows.resize(Levels.ROWS)
	for i in Levels.ROWS:
		var line := rows[i]
		if line.length() < Levels.COLS:
			line = line + "".lpad(Levels.COLS - line.length(), ".")
		rows[i] = line.substr(0, Levels.COLS)
	return rows


static func normalise(room: Dictionary) -> Dictionary:
	return {
		"id": str(room.get("id", new_id())),
		"name": clean_name(str(room.get("name", "ROOM"))),
		"hint": str(room.get("hint", "")),
		"par": maxf(float(room.get("par", 30.0)), 0.0),
		"intensity": clampf(float(room.get("intensity", 1.0)), 0.5, 2.5),
		"dash": bool(room.get("dash", true)),
		"pound": bool(room.get("pound", true)),
		"seed": int(room.get("seed", 0)),
		"author": clean_name(str(room.get("author", ""))),
		"rows": _pad_grid(room.get("rows", [])),
		"backdrop_gravity": _pad_grid(room.get("backdrop_gravity", [])),
		"backdrop_no_dash": _pad_grid(room.get("backdrop_no_dash", [])),
		"backdrop_no_pound": _pad_grid(room.get("backdrop_no_pound", [])),
	}


## The font is uppercase and 5x7; anything it cannot draw is dropped here
## rather than showing up as a hole in a title.
static func clean_name(text: String) -> String:
	var out := ""
	for i in text.to_upper().length():
		var ch := text.to_upper()[i]
		if PixelFont.GLYPHS.has(ch):
			out += ch
	return out.strip_edges().substr(0, NAME_LIMIT)


static func count_char(room: Dictionary, ch: String) -> int:
	var total := 0
	for row: String in room["rows"]:
		total += row.count(ch)
	return total


## Everything wrong with a room, as i18n keys. Empty means playable.
##
## Only two things can actually break Level: no spawn means the player is left
## at the origin, and no door means the room can never end. Both are hard
## errors. The rest is left to the player — a cruel room is not an invalid one.
static func problems(room: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var spawns := count_char(room, "P")
	var doors := count_char(room, "X")
	if spawns == 0:
		out.append("sandbox.err.no_spawn")
	elif spawns > 1:
		out.append("sandbox.err.many_spawn")
	if doors == 0:
		out.append("sandbox.err.no_exit")
	elif doors > 1:
		out.append("sandbox.err.many_exit")
	if count_char(room, "A") > 1:
		out.append("sandbox.err.many_lava")

	# The door is the bottom tile of a two-tile frame, so a door on the top row
	# has nowhere to draw its head.
	for tx in Levels.COLS:
		if room["rows"][0][tx] == "X":
			out.append("sandbox.err.exit_edge")
			break
	return out


static func is_playable(room: Dictionary) -> bool:
	return count_char(room, "P") >= 1 and count_char(room, "X") >= 1


## Strip a room down to what Level and the HUD read. Kept separate from the
## stored dictionary so the editor's own bookkeeping can never leak into a
## running room.
static func to_level_data(room: Dictionary) -> Dictionary:
	return {
		"id": room["id"],
		"name": room["name"],
		"hint": room.get("hint", ""),
		"par": float(room.get("par", 0.0)),
		"intensity": float(room.get("intensity", 1.0)),
		"seed": int(room.get("seed", 0)),
		"rows": room["rows"],
		"backdrop_gravity": room.get("backdrop_gravity", PackedStringArray()),
		"backdrop_no_dash": room.get("backdrop_no_dash", PackedStringArray()),
		"backdrop_no_pound": room.get("backdrop_no_pound", PackedStringArray()),
	}


## A campaign room turned into an editable copy. The campaign stores its name
## and hint as translation keys, so they are resolved to whatever the player is
## reading right now — a room called "level.the_climb.name" on the shelf would
## be worse than useless. The hint is dropped: it belongs to the lesson the
## original room was teaching, not to the copy.
static func from_level(data: Dictionary, fallback_seed: int = 0) -> Dictionary:
	return normalise({
		"id": new_id(),
		"name": Lang.t(str(data.get("name", ""))),
		"hint": "",
		"par": float(data.get("par", 30.0)),
		"intensity": float(data.get("intensity", 1.0)),
		"dash": true,
		"pound": true,
		# Keep the sky the room had, so a copy opens looking like the thing it
		# was copied from rather than like a different room with the same
		# walls. A campaign room carries no seed of its own — Level falls back
		# to its index — so the caller passes that index in.
		"seed": int(data.get("seed", fallback_seed)),
		"rows": data["rows"],
		"backdrop_gravity": data.get("backdrop_gravity", PackedStringArray()),
		"backdrop_no_dash": data.get("backdrop_no_dash", PackedStringArray()),
		"backdrop_no_pound": data.get("backdrop_no_pound", PackedStringArray()),
	})


static func duplicate_room(room: Dictionary) -> Dictionary:
	var copy := normalise(room)
	copy["id"] = new_id()
	copy["name"] = clean_name(copy["name"].substr(0, NAME_LIMIT - 5) + " COPY")
	return copy


# ------------------------------------------------------------------ store ---

static func all() -> Array:
	if not _loaded:
		_load()
	return _rooms


static func _load() -> void:
	_loaded = true
	_rooms = []
	if not FileAccess.file_exists(STORE):
		return
	var f := FileAccess.open(STORE, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for entry in parsed.get("rooms", []):
		if typeof(entry) == TYPE_DICTIONARY:
			_rooms.append(normalise(entry))


static func save() -> void:
	var out: Array = []
	for room: Dictionary in _rooms:
		out.append(_as_json(room))
	var f := FileAccess.open(STORE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": VERSION, "rooms": out}, "\t"))
	f.close()


## PackedStringArray is not a JSON type, so rows go out as a plain array — and
## as one string per line, which is what makes an exported room readable.
static func _as_json(room: Dictionary) -> Dictionary:
	var copy := room.duplicate()
	copy["rows"] = Array(room["rows"] as PackedStringArray)
	if room.has("backdrop_gravity"):
		copy["backdrop_gravity"] = Array(room["backdrop_gravity"] as PackedStringArray)
	if room.has("backdrop_no_dash"):
		copy["backdrop_no_dash"] = Array(room["backdrop_no_dash"] as PackedStringArray)
	if room.has("backdrop_no_pound"):
		copy["backdrop_no_pound"] = Array(room["backdrop_no_pound"] as PackedStringArray)
	return copy


static func add(room: Dictionary) -> int:
	if all().size() >= MAX_ROOMS:
		return -1
	_rooms.append(normalise(room))
	save()
	return _rooms.size() - 1


static func replace(index: int, room: Dictionary) -> void:
	if index < 0 or index >= all().size():
		return
	_rooms[index] = normalise(room)
	save()


static func remove(index: int) -> void:
	if index < 0 or index >= all().size():
		return
	_rooms.remove_at(index)
	save()


static func index_of_id(room_id: String) -> int:
	for i in all().size():
		if _rooms[i]["id"] == room_id:
			return i
	return -1


# ------------------------------------------------------- import / export ---

static func room_to_text(room: Dictionary) -> String:
	return JSON.stringify({
		"format": FORMAT,
		"version": VERSION,
		"game": "PIXEL",
		"room": _as_json(normalise(room)),
	}, "\t")


static func pack_to_text(rooms: Array) -> String:
	var out: Array = []
	for room: Dictionary in rooms:
		out.append(_as_json(normalise(room)))
	return JSON.stringify({
		"format": FORMAT_PACK,
		"version": VERSION,
		"game": "PIXEL",
		"rooms": out,
	}, "\t")


## Every room in a share payload, whatever shape it arrived in: a single room,
## a pack of them, or a bare room dictionary someone typed by hand.
static func rooms_from_text(text: String) -> Array:
	var body := text.strip_edges()
	if body.begins_with(CODE_PREFIX):
		body = decode(body)
		if body.is_empty():
			return []

	var parsed = JSON.parse_string(body)
	if typeof(parsed) != TYPE_DICTIONARY:
		return []

	if parsed.has("rooms"):
		var out: Array = []
		for entry in parsed["rooms"]:
			if typeof(entry) == TYPE_DICTIONARY and entry.has("rows"):
				out.append(normalise(entry))
		return out
	if parsed.has("room") and typeof(parsed["room"]) == TYPE_DICTIONARY:
		return [normalise(parsed["room"])]
	if parsed.has("rows"):
		return [normalise(parsed)]
	return []


## Deflate and base64, for pasting a room into a chat window. The prefix is
## part of the payload so a half-copied code fails loudly instead of decoding
## into nonsense.
static func encode(room: Dictionary) -> String:
	var raw := room_to_text(room).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	return CODE_PREFIX + Marshalls.raw_to_base64(packed)


static func decode(code: String) -> String:
	var body := code.strip_edges()
	if not body.begins_with(CODE_PREFIX):
		return ""
	var packed := Marshalls.base64_to_raw(body.substr(CODE_PREFIX.length()))
	if packed.is_empty():
		return ""
	var raw := packed.decompress_dynamic(CODE_LIMIT, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return ""
	return raw.get_string_from_utf8()


## Downloads, because that is where a room somebody sent you already is, and
## the one folder a person can find without being told a path. Falls back to a
## folder beside the save file where the system has no downloads directory —
## the web build, mainly.
static func export_dir() -> String:
	var downloads := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if not downloads.is_empty() and DirAccess.dir_exists_absolute(downloads):
		return downloads
	DirAccess.make_dir_recursive_absolute(EXPORT_FALLBACK)
	return EXPORT_FALLBACK


## Write one room out. Returns the path a human can open, or an empty string if
## the disk said no.
static func export_room(room: Dictionary) -> String:
	return _write(export_dir().path_join("%s.%s" % [_file_stem(room), EXT]),
		room_to_text(room))


static func export_all(rooms: Array) -> String:
	if rooms.is_empty():
		return ""
	return _write(export_dir().path_join("pixel_pack.%s" % EXT), pack_to_text(rooms))


static func _write(path: String, text: String) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	return ProjectSettings.globalize_path(path)


static func _file_stem(room: Dictionary) -> String:
	var stem := str(room.get("name", "")).to_lower()
	var safe := ""
	for i in stem.length():
		var ch := stem[i]
		safe += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	safe = safe.strip_edges().trim_prefix("_").trim_suffix("_")
	return safe if not safe.is_empty() else str(room.get("id", "room"))


## Files waiting to be imported: whatever is in Downloads, anything dropped in
## user://rooms, and loose share files sitting beside the save. Downloads comes
## first because a room a friend sent lands there without the player doing
## anything. Returns [{path, label}].
##
## Only user://rooms is read loosely enough to accept a bare .json. Downloads
## is a folder full of everybody else's things — service account keys, exported
## calendars, whiteboards — and scanning it for .json turned the import list
## into sixteen files that are not rooms and one that is.
static func drop_files() -> Array:
	var out: Array = []
	var seen := {}
	DirAccess.make_dir_recursive_absolute(DROP_DIR)

	for dir: String in [export_dir(), DROP_DIR, "user://", EXPORT_FALLBACK]:
		if seen.has(dir):
			continue
		seen[dir] = true
		var da := DirAccess.open(dir)
		if da == null:
			continue

		var files := da.get_files()
		files.sort()
		for file: String in files:
			var loose := dir == DROP_DIR and file.ends_with(".json")
			if not (file.ends_with("." + EXT) or loose):
				continue
			# The save and the shelf are not rooms, wherever they turn up.
			if file == "saves.json" or file == "sandbox.json" or file == "save.json":
				continue
			# The same room can sit in two of these folders at once, so the
			# label says which one this copy is in.
			out.append({
				"path": dir.path_join(file),
				"label": "%s/%s" % [_folder_tag(dir), file.to_upper()],
			})
	return out


static func _folder_tag(dir: String) -> String:
	var tag := dir.trim_suffix("/").get_file()
	return tag.to_upper() if not tag.is_empty() else "USER"


static func read_file(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text()
	f.close()
	return rooms_from_text(text)


## Take rooms into the store, giving each a fresh id so importing the same file
## twice makes two rooms rather than overwriting the first.
static func import_rooms(rooms: Array) -> int:
	var added := 0
	for room: Dictionary in rooms:
		var copy := normalise(room)
		if index_of_id(copy["id"]) >= 0:
			copy["id"] = new_id()
		if add(copy) < 0:
			break
		added += 1
	return added


# -------------------------------------------------------------- shipped ---

## Rooms in res://rooms/, appended to the campaign in filename order. This is
## the "put it on the official map" path: drop the exported file in that
## folder and the game finds it at boot, no code change anywhere.
##
## Cached, because Levels.all() runs on several screens and hitting the disk
## every time would show up on the room select.
static func pack_rooms() -> Array:
	if _pack_loaded:
		return _pack
	_pack_loaded = true
	_pack = []

	var da := DirAccess.open(PACK_DIR)
	if da == null:
		return _pack

	var files := da.get_files()
	files.sort()
	for file: String in files:
		# Godot renames imported text files; the packed build sees the .remap.
		var stem := file.trim_suffix(".remap")
		if not (stem.ends_with("." + EXT) or stem.ends_with(".json")):
			continue
		for room: Dictionary in read_file(PACK_DIR.path_join(stem)):
			if not is_playable(room):
				push_warning("Sandbox: %s has no spawn or no exit, skipped" % stem)
				continue
			var data := to_level_data(room)
			# Campaign rooms are keyed by id in the save file, so a shipped
			# room needs one that cannot collide with a hand-written level id.
			data["id"] = "pack_" + str(room["id"])
			_pack.append(data)
	return _pack
