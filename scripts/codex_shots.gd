extends Node

## Autoload. Keeps a small screenshot of the moment each codex entry was first
## met, so the book shows what actually happened instead of a stand-in icon.
##
## A request does not grab the framebuffer straight away. Discoveries arrive in
## bursts — a room build meets a saw, a spike and a spring in the same call —
## so requests queue up and the whole batch is cut out of one single frame grab.
## Reading the framebuffer is the expensive part; cropping it seven times is not.
##
## Shots live as PNGs under user://codex/slot<n>/, one directory per save slot:
## the book belongs to a playthrough, so clearing a slot has to take its
## pictures with it.

const ROOT := "user://codex"
const SHOT := Vector2i(88, 64)  # thumbnail size, in game pixels

var _pending: Array[Dictionary] = []
var _busy := false
var _cache: Dictionary = {}
## Bumped by cancel(). A batch already waiting on frame_post_draw checks this
## before writing, so a room torn down mid-grab cannot have its shot land on
## whatever screen replaced it.
var _generation := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _busy or _pending.is_empty():
		return

	# Requests wait out their own delay first. A room's tiles are discovered
	# while the screen wipe still covers everything, so photographing them on
	# the next frame would capture the transition, not the room.
	# Not named `ready`: Node already has a signal by that name.
	var due: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for req: Dictionary in _pending:
		req["wait"] = float(req["wait"]) - delta
		if float(req["wait"]) <= 0.0:
			due.append(req)
		else:
			waiting.append(req)
	_pending = waiting

	if due.is_empty():
		return
	_busy = true
	_flush(due)


# ------------------------------------------------------------------- paths ---

func _slot_dir(slot: int = -1) -> String:
	var index := slot if slot >= 0 else Save.active
	return "%s/slot%d" % [ROOT, index]


func path(id: String, slot: int = -1) -> String:
	return "%s/%s.png" % [_slot_dir(slot), id]


func has(id: String) -> bool:
	return FileAccess.file_exists(path(id))


## Cache is keyed per slot, since the same entry id has a different picture in
## every playthrough.
func _key(id: String) -> String:
	return "%d/%s" % [Save.active, id]


# ------------------------------------------------------------------ record ---

## Ask for a shot of `world_pos` to stand for `id`. Cheap and safe to call on
## every discovery: entries that already have a picture are ignored, so the
## first time you met something stays the picture you keep.
##
## `delay` holds the grab back. An ability wants zero — the move is happening
## right now — while a tile met during a room build has to wait for the screen
## wipe to finish uncovering the room.
func request(id: String, world_pos: Vector2, delay: float = 0.0) -> void:
	if id.is_empty() or has(id):
		return
	for req: Dictionary in _pending:
		if req["id"] == id:
			return
	_pending.append({"id": id, "pos": world_pos, "wait": delay})


## Drop anything still queued. Called when a room is torn down, so a shot never
## lands after the level it was meant to photograph is gone.
func cancel() -> void:
	_pending.clear()
	_generation += 1


func _flush(batch: Array[Dictionary]) -> void:
	var gen := _generation

	# The frame has to finish drawing before the framebuffer holds it.
	await RenderingServer.frame_post_draw

	if gen != _generation:
		_busy = false
		return

	var viewport := get_viewport()
	if viewport == null:
		_busy = false
		return
	var frame := viewport.get_texture().get_image()
	if frame == null or frame.get_width() <= 0:
		_busy = false
		return

	DirAccess.make_dir_recursive_absolute(_slot_dir())
	var canvas := viewport.get_canvas_transform()
	for req: Dictionary in batch:
		_write(frame, canvas, req)
	_busy = false


func _write(frame: Image, canvas: Transform2D, req: Dictionary) -> void:
	# The framebuffer is the full window, not 480x270 — but when the window's
	# aspect does not match the design aspect (a resized or maximised debug
	# window, almost always), "keep" stretch pillarboxes it: bars of nothing
	# down the sides or across top and bottom. frame.get_width() includes
	# those bars, so dividing it by BASE_W overstated the scale by however wide
	# the bars were, which inflated the crop box until it swallowed the whole
	# subject and grabbed empty background around it instead — the "black box"
	# on some entries. canvas.get_scale() is the transform Godot itself uses to
	# place canvas items in that window, bars already accounted for, so it is
	# the actual pixels-per-design-pixel ratio regardless of window shape.
	var scale := canvas.get_scale()
	var box := Vector2(SHOT) * scale
	var screen: Vector2 = canvas * (req["pos"] as Vector2)

	var rect := Rect2i(
		Vector2i(roundi(screen.x - box.x * 0.5), roundi(screen.y - box.y * 0.5)),
		Vector2i(maxi(1, roundi(box.x)), maxi(1, roundi(box.y))))

	# Slide the window inside the frame rather than clipping it, so a discovery
	# at the edge of the room still yields a full-size picture.
	rect.position.x = clampi(rect.position.x, 0, maxi(0, frame.get_width() - rect.size.x))
	rect.position.y = clampi(rect.position.y, 0, maxi(0, frame.get_height() - rect.size.y))
	rect.size.x = mini(rect.size.x, frame.get_width())
	rect.size.y = mini(rect.size.y, frame.get_height())
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	var shot := frame.get_region(rect)
	shot.resize(SHOT.x, SHOT.y, Image.INTERPOLATE_NEAREST)
	if _looks_blank(shot):
		return
	shot.save_png(path(req["id"]))
	_cache.erase(_key(req["id"]))


## True when a shot is close enough to one flat colour to be nothing —
## background caught with no subject in frame, the failure mode a wrong crop
## scale produces. Refusing to save one of these means a bad grab just leaves
## the entry without a photograph instead of with an ugly empty rectangle.
func _looks_blank(img: Image) -> bool:
	var first := img.get_pixel(0, 0)
	var step_x := maxi(1, img.get_width() / 8)
	var step_y := maxi(1, img.get_height() / 8)
	var x := 0
	while x < img.get_width():
		var y := 0
		while y < img.get_height():
			if img.get_pixel(x, y).distance_to(first) > 0.05:
				return false
			y += step_y
		x += step_x
	return true


# ------------------------------------------------------------------- recall ---

## Texture for an entry, or null when it was met before shots existed (or the
## write failed). Callers fall back to the entry's icon.
func texture(id: String) -> Texture2D:
	var key := _key(id)
	if _cache.has(key):
		return _cache[key]

	var file := path(id)
	if not FileAccess.file_exists(file):
		return null
	var bytes := FileAccess.get_file_as_bytes(file)
	if bytes.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return null

	# Self-heals saves from before the pillarbox scale fix: a shot written with
	# the wrong crop size landed on empty background and got saved as one flat
	# colour. Clearing it here means it just stops showing, once, rather than
	# every future visit to this page redrawing a blank rectangle forever.
	if _looks_blank(img):
		DirAccess.remove_absolute(file)
		return null

	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Throw away one slot's pictures. Pairs with Save.reset_slot().
func wipe(slot: int) -> void:
	var dir := _slot_dir(slot)
	var listing := DirAccess.open(dir)
	if listing != null:
		for file in listing.get_files():
			DirAccess.remove_absolute("%s/%s" % [dir, file])
	_cache.clear()
