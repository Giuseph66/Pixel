class_name Level
extends Node2D

## Turns one entry from levels.gd into a playable room.
##
## Terrain is baked into a single Image once, and its collision is built by
## merging each row of solid tiles into as few rectangles as possible, so a
## full screen of ground costs a handful of shapes instead of 1,920 of them.

signal completed(time: float, gems: int, total_gems: int)
signal player_died

const TILE := 8
const RESPAWN_DELAY := 0.55

var index := 0
var data: Dictionary = {}
var rows: PackedStringArray = PackedStringArray()

var time := 0.0
var gems_taken := 0
var gems_total := 0
var deaths := 0
## 1.0 in the story; endless winds it up with depth.
var intensity := 1.0
## Endless sets both true; the story asks Save which rooms are open yet.
var dash_unlocked := true
var pound_unlocked := true
var running := false
var finished := false

var fx: Fx

var _base_position := Vector2.ZERO
var _shake := 0.0
var _terrain: Sprite2D
var _background: Sprite2D
var _entities: Node2D
var _bodies: Node2D
var _player: Player
var _door: ExitDoor
var _spawn := Vector2.ZERO


func setup(level_index: int, level_data: Dictionary) -> void:
	index = level_index
	data = level_data
	rows = level_data["rows"]
	intensity = float(level_data.get("intensity", 1.0))


func _ready() -> void:
	_base_position = position

	_background = Sprite2D.new()
	_background.centered = false
	_background.texture = _bake_background()
	add_child(_background)

	_terrain = Sprite2D.new()
	_terrain.centered = false
	_terrain.texture = _bake_terrain()
	add_child(_terrain)

	_bodies = Node2D.new()
	add_child(_bodies)
	_build_collision()

	_entities = Node2D.new()
	add_child(_entities)

	fx = Fx.new()
	add_child(fx)

	_spawn_entities()
	running = true


func _process(delta: float) -> void:
	if running and not finished:
		time += delta

	if _shake > 0.0:
		_shake = maxf(_shake - delta * 26.0, 0.0)
		position = _base_position + Vector2(
			randi_range(-1, 1) * roundi(_shake),
			randi_range(-1, 1) * roundi(_shake)
		)
	elif position != _base_position:
		position = _base_position


func shake(amount: float = 3.0) -> void:
	_shake = maxf(_shake, amount)


# ------------------------------------------------------------------ grid ---

func tile_at(tx: int, ty: int) -> String:
	if ty < 0 or ty >= rows.size():
		return "#"
	var row := rows[ty]
	if tx < 0 or tx >= row.length():
		return "#"
	return row[tx]


## Empty air — what a moving platform measures its runway against.
func is_air(tx: int, ty: int) -> bool:
	return tile_at(tx, ty) == "."


func is_solid(tx: int, ty: int) -> bool:
	var ch := tile_at(tx, ty)
	return ch == "#" or ch == "~" or ch == ">" or ch == "<" or ch == "m" or ch == "n" or ch == "r"


## Anything you can stand on, which includes one-way slabs, ice, conveyors, and platforms.
func is_ground(tx: int, ty: int) -> bool:
	var ch := tile_at(tx, ty)
	return ch == "#" or ch == "~" or ch == ">" or ch == "<" or ch == "-" or ch == "m" or ch == "n" or ch == "r"


func tile_center(tx: int, ty: int) -> Vector2:
	return Vector2(tx * TILE + TILE * 0.5, ty * TILE + TILE * 0.5)


# ----------------------------------------------------------------- baking ---

func _bake_background() -> ImageTexture:
	var w := Levels.COLS * TILE
	var h := Levels.ROWS * TILE
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Palette.BG)

	# A fixed seed per level: the sky is different in every room but never
	# changes between attempts.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + index * 977

	for i in 90:
		var x := rng.randi_range(1, w - 2)
		var y := rng.randi_range(1, h - 2)
		img.set_pixel(x, y, Palette.BG_SOFT)
	for i in 24:
		var x := rng.randi_range(1, w - 2)
		var y := rng.randi_range(1, h - 2)
		img.set_pixel(x, y, Palette.FRAME)
	for i in 7:
		var x := rng.randi_range(4, w - 5)
		var y := rng.randi_range(4, h - 5)
		img.set_pixel(x, y, Palette.CYAN_DARK)
		img.set_pixel(x + 1, y, Palette.OUTLINE)

	return ImageTexture.create_from_image(img)


func _bake_terrain() -> ImageTexture:
	var w := Levels.COLS * TILE
	var h := Levels.ROWS * TILE
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for ty in Levels.ROWS:
		for tx in Levels.COLS:
			var ch := tile_at(tx, ty)
			if ch == "#":
				PixelArt.paint_tile(img, tx, ty,
					is_solid(tx, ty - 1),
					is_solid(tx, ty + 1),
					is_solid(tx - 1, ty),
					is_solid(tx + 1, ty))
			elif ch == "~":
				# Ice is painted like terrain but with a different palette
				PixelArt.paint_ice(img, tx, ty,
					is_solid(tx, ty - 1),
					is_solid(tx, ty + 1),
					is_solid(tx - 1, ty),
					is_solid(tx + 1, ty))
			elif ch == ">" or ch == "<":
				# Conveyors are painted as normal ground but with animated sprite on top
				PixelArt.paint_tile(img, tx, ty,
					is_solid(tx, ty - 1),
					is_solid(tx, ty + 1),
					is_solid(tx - 1, ty),
					is_solid(tx + 1, ty))
			elif ch == "-":
				PixelArt.paint_platform(img, tx, ty)

	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------- collision ---

func _build_collision() -> void:
	var solid := StaticBody2D.new()
	solid.collision_layer = 2
	solid.collision_mask = 0
	_bodies.add_child(solid)

	for ty in Levels.ROWS:
		var tx := 0
		while tx < Levels.COLS:
			if not is_solid(tx, ty):
				tx += 1
				continue
			var run := 1
			while tx + run < Levels.COLS and is_solid(tx + run, ty):
				run += 1
			_add_box(solid, tx * TILE, ty * TILE, run * TILE, TILE, false)
			tx += run

	var oneway := StaticBody2D.new()
	oneway.collision_layer = 2
	oneway.collision_mask = 0
	_bodies.add_child(oneway)

	for ty in Levels.ROWS:
		var tx := 0
		while tx < Levels.COLS:
			if tile_at(tx, ty) != "-":
				tx += 1
				continue
			var run := 1
			while tx + run < Levels.COLS and tile_at(tx + run, ty) == "-":
				run += 1
			# Thin slab pinned to the top of the tile: you land on it, but you
			# can also jump straight up through it.
			_add_box(oneway, tx * TILE, ty * TILE, run * TILE, 3, true)
			tx += run


func _add_box(body: StaticBody2D, x: int, y: int, w: int, h: int, one_way: bool) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	shape.position = Vector2(x + w * 0.5, y + h * 0.5)
	shape.one_way_collision = one_way
	shape.one_way_collision_margin = 2.0
	body.add_child(shape)


# ------------------------------------------------------------- entities ---

func _spawn_entities() -> void:
	gems_total = 0
	gems_taken = 0

	for ty in Levels.ROWS:
		for tx in Levels.COLS:
			var ch := tile_at(tx, ty)
			match ch:
				"o":
					var gem := Gem.new()
					gem.position = tile_center(tx, ty)
					gem.collected.connect(_on_gem_collected)
					_entities.add_child(gem)
					gems_total += 1
				"^", "v":
					var spike := Spike.new()
					spike.setup(ch == "v")
					spike.position = tile_center(tx, ty)
					_entities.add_child(spike)
				"J":
					var spring := Spring.new()
					spring.position = tile_center(tx, ty)
					_entities.add_child(spring)
				"S":
					var slime := Slime.new()
					slime.speed_scale = intensity
					slime.position = tile_center(tx, ty)
					slime.is_wall = Callable(self, "is_solid")
					slime.is_ground = Callable(self, "is_ground")
					slime.squashed.connect(_on_slime_squashed)
					_entities.add_child(slime)
				"W":
					var saw := Saw.new()
					saw.speed_scale = intensity
					saw.position = tile_center(tx, ty)
					saw.is_wall = Callable(self, "is_solid")
					saw.is_ground = Callable(self, "is_ground")
					_entities.add_child(saw)
				"B":
					var bat := Bat.new()
					bat.speed_scale = intensity
					bat.position = tile_center(tx, ty)
					bat.squashed.connect(_on_bat_squashed)
					_entities.add_child(bat)
				"c":
					var block := Crumble.new()
					block.position = tile_center(tx, ty)
					_entities.add_child(block)
				"k":
					var breakable := Breakable.new()
					breakable.position = tile_center(tx, ty)
					breakable.broken.connect(_on_block_broken)
					_entities.add_child(breakable)
				"d":
					var crystal := DashCrystal.new()
					crystal.position = tile_center(tx, ty)
					_entities.add_child(crystal)
				"t", "T":
					var timed := TimedBlock.new()
					timed.inverted = ch == "T"
					timed.speed_scale = intensity
					timed.position = tile_center(tx, ty)
					_entities.add_child(timed)
				"z", "Z":
					var retract := RetractSpike.new()
					retract.setup(ch == "Z")
					retract.speed_scale = intensity
					retract.position = tile_center(tx, ty)
					_entities.add_child(retract)
				"X":
					_door = ExitDoor.new()
					# 'X' marks the bottom tile of a two-tile-tall frame.
					_door.position = tile_center(tx, ty) + Vector2(TILE * 0.5, -TILE * 0.5)
					_door.entered.connect(_on_door_entered)
					_entities.add_child(_door)
				"P":
					_spawn = Vector2(
						tx * TILE + TILE * 0.5,
						ty * TILE + TILE - Player.HEIGHT * 0.5
					)

	_spawn_conveyors()
	_spawn_platforms()
	_spawn_player()
	_discover_contents()


## Walk the grid once and open a codex page for anything in it. Seeing counts:
## a saw you never touched is still a saw you have now met.
func _discover_contents() -> void:
	for ty in Levels.ROWS:
		var row := rows[ty]
		for tx in row.length():
			var id: String = Codex.BY_TILE.get(row[tx], "")
			if not id.is_empty():
				Save.discover(id)

	# Slimes watch the player themselves, so they need the reference the moment
	# it exists — which is only after the whole grid has been walked.
	for child in _entities.get_children():
		if child is Slime:
			(child as Slime).player = _player

	_update_door_charge()


## Conveyors are runs of tiles rather than single ones, so they get
## their own pass: '>' pushes right, '<' pushes left.
func _spawn_conveyors() -> void:
	for ty in Levels.ROWS:
		var tx := 0
		while tx < Levels.COLS:
			var ch := tile_at(tx, ty)
			if ch != ">" and ch != "<":
				tx += 1
				continue
			var run := 1
			while tx + run < Levels.COLS and tile_at(tx + run, ty) == ch:
				run += 1

			var conveyor := Conveyor.new()
			conveyor.setup(1 if ch == ">" else -1, float(run * 8))
			conveyor.position = Vector2(float(tx * 8), float(ty * 8))
			_entities.add_child(conveyor)
			tx += run


## Moving platforms are runs of tiles rather than single ones, so they get
## their own pass: 'm' travels sideways, 'n' up and down, 'r' orbits, and the
## length of the run is the length of the slab.
func _spawn_platforms() -> void:
	for ty in Levels.ROWS:
		var tx := 0
		while tx < Levels.COLS:
			var ch := tile_at(tx, ty)
			if ch != "m" and ch != "n" and ch != "r":
				tx += 1
				continue
			var run := 1
			while tx + run < Levels.COLS and tile_at(tx + run, ty) == ch:
				run += 1

			var platform := MovingPlatform.new()
			platform.speed_scale = intensity
			platform.setup(run, ch == "n", tx, ty, Callable(self, "is_air"), ch == "r")
			platform.position = tile_center(tx, ty)
			_entities.add_child(platform)
			tx += run


func _spawn_player() -> void:
	_player = Player.new()
	_player.position = _spawn
	_player.fx = fx
	_player.dash_unlocked = dash_unlocked
	_player.pound_unlocked = pound_unlocked
	_player.surface_at = Callable(self, "tile_at")
	_player.died.connect(_on_player_died)
	_player.pounded.connect(_on_player_pounded)
	_entities.add_child(_player)


func get_player() -> Player:
	return _player


# --------------------------------------------------------------- events ---

func _on_gem_collected(gem: Gem) -> void:
	gems_taken += 1
	Save.add_gem()
	Audio.play("gem", 1.0 + gems_taken * 0.03)
	var at := fx.to_local(gem.global_position)
	fx.emit(at, 10, Palette.GOLD, 80.0, Vector2.ZERO, TAU, 0.4, 180.0)
	fx.popup(at, "+1", Palette.GOLD)
	gem.queue_free()
	_update_door_charge()


## A ground pound clears the ground it lands on: blocks give way, and anything
## standing right there is squashed. The player does not know what is nearby,
## so the level answers for it.
func _on_player_pounded(at: Vector2) -> void:
	shake(5.0)
	fx.emit(fx.to_local(at), 16, Palette.CYAN, 110.0, Vector2.UP, PI, 0.4, 220.0)

	for child in _entities.get_children():
		var distance := at.distance_to((child as Node2D).global_position)
		if child is Breakable and distance <= Player.POUND_REACH + 6.0:
			(child as Breakable).shatter()
		elif child is Slime and distance <= Player.POUND_REACH:
			(child as Slime).die()
		elif child is Bat and distance <= Player.POUND_REACH:
			(child as Bat).die()


func _on_block_broken(at: Vector2) -> void:
	Audio.play_varied("break")
	fx.emit(fx.to_local(at), 12, Palette.GOLD, 95.0, Vector2.ZERO, TAU, 0.45, 260.0)


func _on_bat_squashed(at: Vector2) -> void:
	fx.emit(fx.to_local(at), 12, Palette.PURPLE, 90.0, Vector2.UP, PI, 0.4, 260.0)
	shake(2.0)


func _on_slime_squashed(at: Vector2) -> void:
	fx.emit(fx.to_local(at), 12, Palette.GREEN, 90.0, Vector2.UP, PI, 0.4, 260.0)
	shake(2.0)


func _update_door_charge() -> void:
	if _door == null:
		return
	_door.charge = 1.0 if gems_total == 0 else float(gems_taken) / float(gems_total)


func _on_door_entered() -> void:
	if finished:
		return
	finished = true
	running = false
	if _player != null:
		_player.enter_door(_door.global_position)
	Audio.play("door")
	fx.emit(_door.position, 24, Palette.PURPLE, 90.0, Vector2.ZERO, TAU, 0.7, 90.0)
	completed.emit(time, gems_taken, gems_total)


func _on_player_died() -> void:
	if finished:
		return
	deaths += 1
	Save.add_death()
	shake(4.0)
	player_died.emit()
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if is_inside_tree() and not finished:
		restart()


## Rebuild everything that can be interacted with. Terrain and collision are
## untouched — they never change.
func restart() -> void:
	finished = false
	for child in _entities.get_children():
		# Detach first so a dying gem or slime cannot fire one last signal.
		_entities.remove_child(child)
		child.queue_free()
	fx.clear()
	_door = null
	_spawn_entities()
	running = true
