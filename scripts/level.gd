class_name Level
extends Node2D

## Turns one entry from levels.gd into a playable room.
##
## Terrain is baked into a single Image once, and its collision is built by
## merging each row of solid tiles into as few rectangles as possible, so a
## full screen of ground costs a handful of shapes instead of 1,920 of them.

signal completed(time: float, gems: int, total_gems: int, score: int, best_combo: int)
signal player_died

const TILE := 8
const RESPAWN_DELAY := 0.55

var index := 0
var data: Dictionary = {}
var rows: PackedStringArray = PackedStringArray()
## What the room's fixed randomness is drawn from — the star field behind it
## and the height of each retracting blade. It is the room index in the
## campaign, so nothing there changes; a sandbox room carries its own, which is
## what lets the editor re-roll a starfield without moving a single tile.
var art_seed := 0

var time := 0.0
var gems_taken := 0
var gems_total := 0
var secrets_taken := 0
var deaths := 0
## Step 10 — score is 100*n*n per combo cashed in on landing; best_combo is the
## longest chain of distinct verbs the room saw, whatever it scored.
var score := 0
var best_combo := 0
## Step 12 — one boolean for the whole room. Every switch pad flips it; every
## gate reads it. No per-gate wiring, because a room is one screen and the
## player can already see everything that just changed.
var switch_state := false
var _gates: Array = []
var _switches: Array = []
## Step 24 — clone fantasma. Recording is level-wide state, not the player's:
## it starts on touching 'y' and runs a fixed span regardless of what the
## player does with it, so it lives here rather than on Player the way echo's
## own buffer does.
const RECORD_TIME := 5.0        # seconds captured before the clone is born
var _recording := false
var _record_buffer: PackedVector2Array = PackedVector2Array()
var _record_t := 0.0
var _sensors: Array = []
## Step 14 — phase blocks. A block is intangible while anyone in the room is
## mid-dash, so this tracks who currently is rather than trusting a single
## player's state in a mode where more than one can exist.
var _phase_blocks: Array = []
var _dashing: Dictionary = {}
## Step 16 — a switch also buys a few safe seconds against any laser in the
## room, not just the gates. See toggle_switch().
var _lasers: Array = []
## Step 15 — portals. One pair per room; linked after the whole grid is
## walked, since whichever one the scan reaches second does not exist yet
## when the first is created.
var _portal_a: Portal = null
var _portal_b: Portal = null
## 1.0 in the story; endless winds it up with depth.
var intensity := 1.0
## Endless sets both true; the story asks Save which rooms are open yet.
var dash_unlocked := true
var pound_unlocked := true
## Bombado (doc/bombadao). Defaults false, the opposite of the two above,
## because it is the exception rather than the rule: main.gd turns it on for
## sandbox rooms only, and every other caller — including the smoke test —
## gets a room where the key does nothing.
var buff_unlocked := false
## Built the first time the local player actually turns, torn down when they
## turn back. Nothing exists on screen for a room whose player never uses it.
var _buff_aura: BuffAura
## The room never sits perfectly still while he is on it. Small enough that
## you read it as weight rather than as a screen shake.
const BUFF_RUMBLE := 0.9
const BUFF_RUMBLE_SHAKE := 0.8
var _buff_rumble := 0.0
## Step 23 — echo. Read from the room's own data in setup(), not set by
## main.gd like the two above: the ability belongs to specific rooms, not to
## story progress, so there is no mode-wide rule to apply here.
var echo_max := 0
## Step 20 — endless modifiers. main.gd sets these before add_child(); Level
## only has to forward them to whatever player it spawns, and to build the
## darkness overlay when asked. "brittle" needs none of this — it is baked
## straight into the room's tiles by LevelGen, before Level ever sees them.
var player_speed_scale := 1.0
var player_gravity_scale := 1.0
var dark := false
var _darkness: Darkness
## Step 25 — personal-best ghost. main.gd sets both before add_child(), the
## same way it hands over dash_unlocked: ghost_enabled is false for endless
## and sandbox rooms (Save.record_endless()/sandbox results never compare to
## a ghost), and is_remix picks the "r"-prefixed namespace GhostStore keeps
## separate from the campaign's own.
var ghost_enabled := false
var is_remix := false
var last_recording: PackedVector2Array = PackedVector2Array()
## Sample indices (into last_recording) where the player landed a ground
## pound — the one ghost pose that is a one-shot event, not something a
## flip_v read off the room's own gravity zones can reconstruct on its own.
var last_recording_pounds: PackedInt32Array = PackedInt32Array()
var _ghost_player: GhostPlayer
var _ghost_sample_t := 0.0
var running := false
var finished := false

var fx: Fx

var _base_position := Vector2.ZERO
var _shake := 0.0
var _terrain: Sprite2D
var _gravity_layer: Sprite2D
## Step 22 — the BACKDROP category. A zone's real extent, one rect per
## contiguous patch of 'V' the room's grid has — see _find_gravity_zones().
var _gravity_zones: Array[Rect2i] = []
## Fundo backdrops added after gravity: their own parallel grids instead of a
## character sharing the main one, so a no-dash zone, a no-pound zone, a
## gravity zone and an ordinary wall/creature/gem can all sit on the same
## cell at once — see _bake_mod_zones().
var _mod_layer: Sprite2D
## The sandbox editor's own gravity zones — painted onto their own grid same
## as no_dash/no_pound, so a room built there can stack 'V' with a wall, a
## creature or another Fundo tile in one cell. is_in_gravity_zone() checks
## this in addition to _gravity_zones (the legacy rect mechanism below),
## which stays exactly as it was for the campaign rooms built before this
## grid existed.
var _gravity_rows: PackedStringArray = PackedStringArray()
var _no_dash_rows: PackedStringArray = PackedStringArray()
var _no_pound_rows: PackedStringArray = PackedStringArray()
var _background: Sprite2D
var _entities: Node2D
var _bodies: Node2D
var _player: Player
var _players: Dictionary = {}
var _door: ExitDoor
var _lava: Lava
var _spawn := Vector2.ZERO
var _snapshot_time := 0.0
var _door_arrivals: Dictionary = {}
var _pending_respawns: Dictionary = {}
var competitive := false


func setup(level_index: int, level_data: Dictionary) -> void:
	index = level_index
	data = level_data
	rows = level_data["rows"]
	intensity = float(level_data.get("intensity", 1.0))
	art_seed = int(level_data.get("seed", level_index))
	# Step 23 — echo. Absent everywhere except the four rooms built for it;
	# 0 there means the ability does not exist, not that it is merely unused.
	echo_max = int(level_data.get("echo", 0))
	_gravity_rows = level_data.get("backdrop_gravity", PackedStringArray())
	_no_dash_rows = level_data.get("backdrop_no_dash", PackedStringArray())
	_no_pound_rows = level_data.get("backdrop_no_pound", PackedStringArray())


func _ready() -> void:
	_base_position = position

	_background = Sprite2D.new()
	_background.centered = false
	_background.texture = _bake_background()
	add_child(_background)

	# Step 22 — computed once, before anything paints over a 'V' cell: a gem
	# or any other entity character landing inside the zone's own tiles
	# overwrites that cell in the room's baked string, and a check that only
	# ever asked "is this exact tile still 'V'" would lose the zone right
	# there — gravity flips back off for one tile-sized patch, exactly under
	# whatever is sitting on it. The bounding box of each contiguous patch of
	# 'V' survives that hole, so the zone's real extent is what a room author
	# drew, not whatever characters happen to still say 'V' after every gem
	# and marker has landed on top of it.
	_gravity_zones = _find_gravity_zones()

	# Its own layer, between the background and the terrain, so a gravity
	# zone reads as a tinted wall sitting behind the room instead of a
	# texture painted onto the same layer real solid blocks are — and filled
	# from _gravity_zones rather than from individual 'V' tiles, for the same
	# hole-under-a-gem reason.
	_gravity_layer = Sprite2D.new()
	_gravity_layer.centered = false
	_gravity_layer.texture = _bake_gravity_zones()
	add_child(_gravity_layer)

	# Same layer depth as gravity, for the same reason: a backdrop, not a
	# texture on a real block.
	_mod_layer = Sprite2D.new()
	_mod_layer.centered = false
	_mod_layer.texture = _bake_mod_zones()
	add_child(_mod_layer)

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
	if dark:
		_darkness = Darkness.new()
		_darkness.player = _player
		_darkness.glow_provider = Callable(self, "_dark_glow_positions")
		add_child(_darkness)
	if ghost_enabled:
		var loaded := GhostStore.load(Save.active, str(data.get("id", "")), is_remix)
		var recorded: PackedVector2Array = loaded["samples"]
		if not recorded.is_empty():
			_ghost_player = GhostPlayer.new()
			_ghost_player.setup(recorded, loaded["pounds"])
			_ghost_player.gravity_zone_at = Callable(self, "is_in_gravity_zone")
			add_child(_ghost_player)
	if Session.is_active():
		Session.snapshot_received.connect(_on_network_snapshot)
		Session.world_event_received.connect(_on_network_world_event)
		Session.roster_changed.connect(_on_roster_changed)
		if Session.is_host():
			Session.client_state_received.connect(_on_client_player_state)
			Session.player_event_received.connect(_on_client_player_event)
	running = true


func _process(delta: float) -> void:
	if running and not finished:
		time += delta

	_update_sensors()
	_tick_buff_weather(delta)

	if _shake > 0.0:
		_shake = maxf(_shake - delta * 26.0, 0.0)
		position = _base_position + Vector2(
			randi_range(-1, 1) * roundi(_shake),
			randi_range(-1, 1) * roundi(_shake)
		)
	elif position != _base_position:
		position = _base_position


func _physics_process(delta: float) -> void:
	# Recording runs unconditionally — offline, online, host or not — because
	# it is sampling the local player's own position, the same thing every
	# other per-frame read in this file (previous_bottom, ground_tile) does.
	if _recording and running and not finished:
		_record_t += delta
		if _record_t <= RECORD_TIME:
			var player := get_player()
			if player != null:
				_record_buffer.append(player.global_position)
		else:
			_recording = false
			_spawn_clone()

	# Step 25 — sampled far coarser than physics (20Hz, not 60) because a
	# ghost is a background read, not a hitbox; a run under the 90s cap this
	# buys back in file size instead is the whole reason GhostStore exists.
	if ghost_enabled and running and not finished:
		_ghost_sample_t += delta
		if _ghost_sample_t >= 1.0 / float(GhostStore.SAMPLE_HZ):
			_ghost_sample_t = 0.0
			var player := get_player()
			if player != null and last_recording.size() < GhostStore.MAX_SAMPLES:
				last_recording.append(player.global_position)

	if not Session.is_active() or not Session.is_host() or not running:
		return
	_snapshot_time += delta
	if _snapshot_time < 0.033:
		return
	_snapshot_time = 0.0
	var players: Array = []
	for player: Player in _players.values():
		players.append(player.network_snapshot())
	var entities: Array = []
	for child: Node2D in _entities.get_children():
		if child is Player:
			continue
		var entity_state := {
			"node": str(child.name),
			"x": child.position.x,
			"y": child.position.y,
			"visible": child.visible,
		}
		if child.has_method("network_state"):
			var extra: Dictionary = child.call("network_state")
			for key: Variant in extra:
				entity_state[key] = extra[key]
		entities.append(entity_state)
	Session.publish_snapshot({
		"time": time,
		"gems_taken": gems_taken,
		"gems_total": gems_total,
		"deaths": deaths,
		"players": players,
		"entities": entities,
	})


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


## Empty air — what a moving platform measures its runway against. Wind is not
## terrain (nothing about it blocks movement or gives a platform anywhere to
## rest), so a column of it reads as open air here same as it does everywhere
## else in the grid.
func is_air(tx: int, ty: int) -> bool:
	var ch := tile_at(tx, ty)
	return ch == "." or ch == "u" or ch == "U" or ch == "V"


## Terrain that gets baked into the static collision. Ice and conveyors are
## ordinary walls as far as physics is concerned — what makes them different is
## the friction the player reads off the tile and the entity riding on top.
## Moving platforms are deliberately absent: they carry their own body, and
## marking their spawn tiles solid would leave a wall behind once they move off.
func is_solid(tx: int, ty: int) -> bool:
	var ch := tile_at(tx, ty)
	return ch == "#" or ch == "~" or ch == ">" or ch == "<"


## Anything you can stand on, which includes one-way slabs.
func is_ground(tx: int, ty: int) -> bool:
	var ch := tile_at(tx, ty)
	return is_solid(tx, ty) or ch == "-"


## Which way a portal launches whoever exits it. Inferred from whichever
## neighbour is solid: horizontal first, since a portal set into the side of a
## wall (the common case — it is usually stood on a normal floor too, which
## would otherwise always win a vertical check) means "cross the wall",
## and only a portal with nothing beside it falls back to reading up or down.
## 'L' fires along the row it sits in, 'K' along the column — a designer picks
## the axis with the tile, and only the direction on that axis is inferred
## from context (which side has a wall to mount against). Two separate
## functions rather than one that falls back from horizontal to vertical: that
## fallback was the whole reason a laser boxed in by walls on both axes could
## never be aimed vertically on purpose.
func _laser_facing_h(tx: int, ty: int) -> Vector2:
	if is_solid(tx - 1, ty):
		return Vector2.RIGHT
	if is_solid(tx + 1, ty):
		return Vector2.LEFT
	push_warning("Level: laser at (%d,%d) has no side wall to mount on" % [tx, ty])
	return Vector2.RIGHT


func _laser_facing_v(tx: int, ty: int) -> Vector2:
	# is_ground(), not is_solid(): standing a 'K' on a one-way slab is a normal
	# thing to build, and is_solid() alone does not count "-" as a floor — the
	# same gap that silently mis-aimed a portal sitting on one.
	if is_ground(tx, ty + 1):
		return Vector2.UP
	if is_solid(tx, ty - 1):
		return Vector2.DOWN
	push_warning("Level: laser at (%d,%d) has no floor or ceiling to mount on" % [tx, ty])
	return Vector2.UP


## Where a laser beam re-emerges if it crosses a portal tile mid-flight —
## the twin, same as a body that falls into one: heading swapped for
## whichever way the exit faces. Null before both portals are linked (still
## true the instant a laser's own _ready() takes its first measurement,
## since the grid is walked top to bottom and linking happens only once the
## whole thing has been read) or if the tile just isn't a portal at all.
func _portal_exit_at(tx: int, ty: int) -> Portal:
	var ch := tile_at(tx, ty)
	var portal: Portal = null
	if ch == "q":
		portal = _portal_a
	elif ch == "Q":
		portal = _portal_b
	return portal.twin if portal != null else null


func _portal_facing(tx: int, ty: int) -> Vector2:
	if is_solid(tx - 1, ty):
		return Vector2.RIGHT
	if is_solid(tx + 1, ty):
		return Vector2.LEFT
	# is_ground(), not is_solid(): a portal standing on a one-way slab is a
	# completely normal thing to build (portal_fall and portal_gem both do),
	# and is_solid() alone does not count "-" as anything to stand on. That
	# silently sent both of their exits firing right instead of up.
	if is_ground(tx, ty + 1):
		return Vector2.UP
	if is_solid(tx, ty - 1):
		return Vector2.DOWN
	return Vector2.RIGHT


## What is_solid() cannot see: a gate reads the room's live switch state
## instead of the grid, since the grid never changes after the room is baked.
## Ground AI (Slime, Saw, ElasticSlime, ShieldEnemy) reads this instead of
## is_solid() for "is there a wall ahead" — without it they walk straight
## through a closed gate, because the gate was never part of the baked terrain
## in the first place.
func is_wall_or_gate(tx: int, ty: int) -> bool:
	var ch := tile_at(tx, ty)
	if ch == "g" or ch == "G":
		return switch_state != (ch == "G")
	return is_solid(tx, ty)


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
	rng.seed = 9000 + art_seed * 977

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


## Step 22 — gravity zones, on their own layer behind the terrain. 'V' is air
## as far as physics is concerned (is_air() already says so) — this is only
## the backdrop that tells the player where the rule is about to change.
func _bake_gravity_zones() -> ImageTexture:
	var w := Levels.COLS * TILE
	var h := Levels.ROWS * TILE
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for zone: Rect2i in _gravity_zones:
		for ty in range(zone.position.y, zone.end.y):
			for tx in range(zone.position.x, zone.end.x):
				PixelArt.paint_gravity_zone(img, tx, ty,
					zone.has_point(Vector2i(tx, ty - 1)),
					zone.has_point(Vector2i(tx, ty + 1)),
					zone.has_point(Vector2i(tx - 1, ty)),
					zone.has_point(Vector2i(tx + 1, ty)))

	return ImageTexture.create_from_image(img)


## Whether (tx, ty) sits inside any gravity zone — the check Player runs
## every physics frame. Two sources, checked together: the legacy rect
## mechanism built for campaign rooms (rect containment, not a grid read, for
## the reason _bake_gravity_zones() no longer reads the grid either), and the
## sandbox editor's own backdrop_gravity grid, which never needs a hole
## worked around in the first place — see _mod_row().
func is_in_gravity_zone(tx: int, ty: int) -> bool:
	var p := Vector2i(tx, ty)
	for zone: Rect2i in _gravity_zones:
		if zone.has_point(p):
			return true
	return _mod_row(_gravity_rows, ty, tx)


## One rect per contiguous patch of 'V' cells still present in the room's
## baked string. Flood fill rather than a single global bounding box, so two
## separate zones in the same room never merge into one that also covers the
## ordinary floor between them; and a bounding box rather than exact cell
## membership, so a gem or any other entity character sitting on one of the
## zone's own tiles — puts() overwrites whatever was there — never carves a
## hole out of the zone it landed inside. A hole that does not touch the
## zone's own edge cannot disconnect the fill around it, so the rect comes
## back whole either way.
func _find_gravity_zones() -> Array[Rect2i]:
	var visited: Dictionary = {}
	var zones: Array[Rect2i] = []
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for ty in Levels.ROWS:
		for tx in Levels.COLS:
			var here := Vector2i(tx, ty)
			if tile_at(tx, ty) != "V" or visited.has(here):
				continue
			var stack: Array[Vector2i] = [here]
			visited[here] = true
			var min_p := here
			var max_p := here
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				min_p.x = mini(min_p.x, p.x)
				min_p.y = mini(min_p.y, p.y)
				max_p.x = maxi(max_p.x, p.x)
				max_p.y = maxi(max_p.y, p.y)
				for d: Vector2i in dirs:
					var np := p + d
					if visited.has(np):
						continue
					if tile_at(np.x, np.y) == "V":
						visited[np] = true
						stack.append(np)
			zones.append(Rect2i(min_p, max_p - min_p + Vector2i.ONE))
	return zones


## Fundo — no-dash and no-pound zones. Unlike gravity's 'V', these live on
## their own grids that nothing else ever writes to, so a direct read of
## (tx, ty) is the whole check: no hole-under-a-gem problem to route around,
## because the gem's char lives in `rows`, not here.
func is_no_dash_zone(tx: int, ty: int) -> bool:
	return _mod_row(_no_dash_rows, ty, tx)


func is_no_pound_zone(tx: int, ty: int) -> bool:
	return _mod_row(_no_pound_rows, ty, tx)


func _mod_row(grid: PackedStringArray, ty: int, tx: int) -> bool:
	if ty < 0 or ty >= grid.size():
		return false
	var line: String = grid[ty]
	return tx >= 0 and tx < line.length() and line[tx] != "."


## The sandbox editor's own Fundo grids, painted onto one backdrop layer,
## tinted apart so two zones stacked on the same cell still read as two
## things, not one. Gravity here is _gravity_rows only, deliberately not
## is_in_gravity_zone() — a legacy campaign room's rect gets its checker from
## _gravity_layer already, and painting it a second time here would just be
## the same pattern drawn twice.
func _bake_mod_zones() -> ImageTexture:
	var w := Levels.COLS * TILE
	var h := Levels.ROWS * TILE
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for ty in Levels.ROWS:
		for tx in Levels.COLS:
			if _mod_row(_gravity_rows, ty, tx):
				PixelArt.paint_gravity_zone(img, tx, ty,
					_mod_row(_gravity_rows, ty - 1, tx), _mod_row(_gravity_rows, ty + 1, tx),
					_mod_row(_gravity_rows, ty, tx - 1), _mod_row(_gravity_rows, ty, tx + 1))
			if is_no_dash_zone(tx, ty):
				PixelArt.paint_no_dash_zone(img, tx, ty,
					is_no_dash_zone(tx, ty - 1), is_no_dash_zone(tx, ty + 1),
					is_no_dash_zone(tx - 1, ty), is_no_dash_zone(tx + 1, ty))
			if is_no_pound_zone(tx, ty):
				PixelArt.paint_no_pound_zone(img, tx, ty,
					is_no_pound_zone(tx, ty - 1), is_no_pound_zone(tx, ty + 1),
					is_no_pound_zone(tx - 1, ty), is_no_pound_zone(tx + 1, ty))

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
	secrets_taken = 0
	switch_state = false
	_gates = []
	_switches = []
	_phase_blocks = []
	_dashing = {}
	_lasers = []
	_portal_a = null
	_portal_b = null
	_recording = false
	_record_buffer = PackedVector2Array()
	_record_t = 0.0
	_sensors = []

	for ty in Levels.ROWS:
		for tx in Levels.COLS:
			var ch := tile_at(tx, ty)
			match ch:
				"o":
					var gem := Gem.new()
					gem.name = "gem_%d_%d" % [tx, ty]
					gem.position = tile_center(tx, ty)
					gem.collected.connect(_on_gem_collected)
					_entities.add_child(gem)
					gems_total += 1
				"O":
					var gem := Gem.new()
					gem.name = "secret_%d_%d" % [tx, ty]
					gem.secret = true
					gem.position = tile_center(tx, ty)
					gem.collected.connect(_on_gem_collected)
					_entities.add_child(gem)
				"^", "v":
					var spike := Spike.new()
					spike.setup(ch == "v")
					spike.position = tile_center(tx, ty)
					_entities.add_child(spike)
				"J":
					var spring := Spring.new()
					spring.position = tile_center(tx, ty)
					spring.bounced.connect(_on_spring_bounced.bind(spring))
					_entities.add_child(spring)
				"S":
					var slime := Slime.new()
					slime.speed_scale = intensity
					slime.position = tile_center(tx, ty)
					slime.is_wall = Callable(self, "is_wall_or_gate")
					slime.is_ground = Callable(self, "is_ground")
					slime.squashed.connect(_on_slime_squashed.bind(slime))
					_entities.add_child(slime)
				"W":
					var saw := Saw.new()
					saw.speed_scale = intensity
					saw.position = tile_center(tx, ty)
					saw.is_wall = Callable(self, "is_wall_or_gate")
					saw.is_ground = Callable(self, "is_ground")
					_entities.add_child(saw)
				"B":
					var bat := Bat.new()
					bat.speed_scale = intensity
					bat.position = tile_center(tx, ty)
					bat.squashed.connect(_on_bat_squashed.bind(bat))
					_entities.add_child(bat)
				"c":
					var block := Crumble.new()
					block.position = tile_center(tx, ty)
					block.state_changed.connect(_on_crumble_state_changed.bind(block))
					_entities.add_child(block)
				"k":
					var breakable := Breakable.new()
					breakable.position = tile_center(tx, ty)
					breakable.broken.connect(_on_block_broken.bind(breakable))
					_entities.add_child(breakable)
				"d":
					var crystal := DashCrystal.new()
					crystal.position = tile_center(tx, ty)
					crystal.activated.connect(_on_crystal_activated.bind(crystal))
					_entities.add_child(crystal)
				"t", "T":
					var timed := TimedBlock.new()
					timed.inverted = ch == "T"
					timed.speed_scale = intensity
					timed.position = tile_center(tx, ty)
					_entities.add_child(timed)
				"e":
					var elastic := ElasticSlime.new()
					elastic.speed_scale = intensity
					elastic.position = tile_center(tx, ty)
					elastic.is_wall = Callable(self, "is_wall_or_gate")
					elastic.is_ground = Callable(self, "is_ground")
					elastic.bounced.connect(_on_elastic_bounced.bind(elastic))
					_entities.add_child(elastic)
				"E":
					var shield := ShieldEnemy.new()
					shield.speed_scale = intensity
					shield.position = tile_center(tx, ty)
					shield.is_wall = Callable(self, "is_wall_or_gate")
					shield.is_ground = Callable(self, "is_ground")
					shield.squashed.connect(_on_slime_squashed.bind(shield))
					_entities.add_child(shield)
				"p":
					var phase := PhaseBlock.new()
					phase.position = tile_center(tx, ty)
					_entities.add_child(phase)
					_phase_blocks.append(phase)
				"F":
					var ferry := FerryBat.new()
					ferry.speed_scale = intensity
					ferry.position = tile_center(tx, ty)
					ferry.state_changed.connect(_on_ferry_state_changed.bind(ferry))
					_entities.add_child(ferry)
				"L", "K":
					var laser := Laser.new()
					laser.speed_scale = intensity
					laser.position = tile_center(tx, ty)
					var facing := _laser_facing_h(tx, ty) if ch == "L" else _laser_facing_v(tx, ty)
					# is_wall_or_gate(), not is_solid(): a closed gate is not baked
					# terrain, so is_solid() alone is blind to it — the beam would
					# sail straight through a shut gate the same way ground AI used
					# to walk through one before it got this same swap.
					laser.setup(facing, Callable(self, "is_wall_or_gate"), Callable(self, "_portal_exit_at"))
					_entities.add_child(laser)
					_lasers.append(laser)
				"q", "Q":
					var portal := Portal.new()
					portal.setup(_portal_facing(tx, ty))
					portal.position = tile_center(tx, ty)
					_entities.add_child(portal)
					if ch == "q":
						_portal_a = portal
					else:
						_portal_b = portal
				"i":
					var pad := SwitchPad.new()
					pad.position = tile_center(tx, ty)
					pad.pressed.connect(_on_switch_pressed)
					_entities.add_child(pad)
					_switches.append(pad)
				"y":
					var record_pad := RecordPad.new()
					record_pad.position = tile_center(tx, ty)
					record_pad.touched.connect(_on_record_pad_touched.bind(record_pad))
					_entities.add_child(record_pad)
				"Y":
					var sensor := Sensor.new()
					sensor.position = tile_center(tx, ty)
					_entities.add_child(sensor)
					_sensors.append(sensor)
				"g", "G":
					var gate := GateBlock.new()
					gate.inverted = ch == "G"
					gate.solid = gate.compute_solid(switch_state)
					gate.position = tile_center(tx, ty)
					_entities.add_child(gate)
					_gates.append(gate)
				"A":
					_lava = Lava.new()
					_lava.speed_scale = intensity
					_lava.setup(float(ty * TILE))
					_entities.add_child(_lava)
				"z", "Z":
					var retract := RetractSpike.new()
					retract.speed_scale = intensity
					retract.position = tile_center(tx, ty)
					# A blade of one to three tiles. Both the reach and the roll
					# live on RetractSpike, so the editor's preview and the real
					# blade can never drift apart.
					var air := RetractSpike.air_above(Callable(self, "is_air"), tx, ty)
					retract.setup(ch == "Z", RetractSpike.height_for(art_seed, tx, ty, air))
					_entities.add_child(retract)
				"X":
					_door = ExitDoor.new()
					_door.name = "door_%d_%d" % [tx, ty]
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
	_spawn_wind()
	_spawn_ghost_blocks()
	_stabilize_entity_names()
	_spawn_players()
	_discover_contents()


## Auto-generated Godot names contain process-local instance numbers. Stable
## order-based names let snapshots and gameplay events resolve the same entity
## on every machine.
func _stabilize_entity_names() -> void:
	for i in _entities.get_child_count():
		var child := _entities.get_child(i)
		child.name = "entity_%03d" % i


## Walk the grid once and open a codex page for anything in it. Seeing counts:
## a saw you never touched is still a saw you have now met.
func _discover_contents() -> void:
	for ty in Levels.ROWS:
		var row := rows[ty]
		for tx in row.length():
			var id: String = Codex.BY_TILE.get(row[tx], "")
			if not id.is_empty():
				Save.discover(id)

	# Enemies receive all current players. Offline has one player, preserving the
	# old path; a network host can resolve contact for every peer.
	for child in _entities.get_children():
		if child is Slime:
			(child as Slime).players = get_players()
		elif child is ElasticSlime:
			(child as ElasticSlime).players = get_players()
		elif child is ShieldEnemy:
			(child as ShieldEnemy).players = get_players()
		elif child is FerryBat:
			(child as FerryBat).players = get_players()
		elif child is GhostBlock:
			(child as GhostBlock).players = get_players()
	if _lava != null:
		_lava.players = get_players()
	if Session.is_client():
		_observe_host_world()

	if _portal_a != null and _portal_b != null:
		_portal_a.twin = _portal_b
		_portal_b.twin = _portal_a
	elif _portal_a != null or _portal_b != null:
		# A portal with no twin is a dead tile that looks live — that has to
		# fail loudly during development, not sit quietly in a shipped room.
		push_error("Level: room %s has a 'q' or 'Q' with no matching pair" % str(data.get("id", index)))

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
			conveyor.setup(1 if ch == ">" else -1, run)
			conveyor.position = Vector2(tx * TILE, ty * TILE)
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


## Ghost blocks are runs like conveyors and platforms: one strip node per run
## of matching tiles, not one node per tile. players is wired in
## _discover_contents() afterwards, same as every other player-aware entity —
## _spawn_players() has not run yet when this pass does.
func _spawn_ghost_blocks() -> void:
	for ty in Levels.ROWS:
		var tx := 0
		while tx < Levels.COLS:
			var ch := tile_at(tx, ty)
			if ch != "h" and ch != "H":
				tx += 1
				continue
			var run := 1
			while tx + run < Levels.COLS and tile_at(tx + run, ty) == ch:
				run += 1

			var block := GhostBlock.new()
			block.setup(ch == "H", run)
			block.position = Vector2(tx * TILE, ty * TILE)
			_entities.add_child(block)
			tx += run


func _spawn_players() -> void:
	_players = {}
	_pending_respawns.clear()
	var peer_ids: Array = [1]
	if Session.is_active():
		peer_ids = Session.participants.keys()
		peer_ids.sort()
	for peer_id: int in peer_ids:
		_spawn_player(peer_id)


## Wind is grouped by run like belts and platforms: a column of 'u' pushes up,
## a band of 'U' pushes left. Two passes because one runs down a column and
## the other along a row — the same loop shape cannot walk both.
func _spawn_wind() -> void:
	for tx in Levels.COLS:
		var ty := 0
		while ty < Levels.ROWS:
			if tile_at(tx, ty) != "u":
				ty += 1
				continue
			var run := 1
			while ty + run < Levels.ROWS and tile_at(tx, ty + run) == "u":
				run += 1
			var wind := Wind.new()
			wind.fx = fx
			wind.setup(Vector2.UP, run)
			wind.position = Vector2(tx * TILE, ty * TILE)
			_entities.add_child(wind)
			ty += run

	for ty in Levels.ROWS:
		var tx := 0
		while tx < Levels.COLS:
			if tile_at(tx, ty) != "U":
				tx += 1
				continue
			var run := 1
			while tx + run < Levels.COLS and tile_at(tx + run, ty) == "U":
				run += 1
			var wind := Wind.new()
			wind.fx = fx
			wind.setup(Vector2.LEFT, run)
			wind.position = Vector2(tx * TILE, ty * TILE)
			_entities.add_child(wind)
			tx += run


func _spawn_player(peer_id: int) -> void:
	var player := Player.new()
	player.name = "Player_%d" % peer_id
	player.peer_id = peer_id
	player.networked = Session.is_active()
	player.locally_controlled = peer_id == Session.local_peer_id()
	player.client_authority = player.networked and Session.is_host() and peer_id != 1
	var profile: Dictionary = Session.participants.get(peer_id, {})
	player.color_index = int(profile.get("color", 0))
	player.position = _spawn + Vector2(float((_players.size() % 3) * 3), 0.0)
	player.fx = fx
	player.dash_unlocked = dash_unlocked
	player.pound_unlocked = pound_unlocked
	player.buff_unlocked = buff_unlocked
	player.buff_changed.connect(_on_player_buff_changed.bind(player))
	player.speed_scale = player_speed_scale
	player.gravity_scale = player_gravity_scale
	player.echo_max = echo_max
	player.surface_at = Callable(self, "tile_at")
	player.gravity_zone_at = Callable(self, "is_in_gravity_zone")
	player.no_dash_zone_at = Callable(self, "is_no_dash_zone")
	player.no_pound_zone_at = Callable(self, "is_no_pound_zone")
	player.died.connect(_on_player_died.bind(player))
	player.pounded.connect(_on_player_pounded.bind(player))
	player.combo_changed.connect(_on_combo_changed.bind(player))
	player.combo_ended.connect(_on_combo_ended)
	player.dash_changed.connect(_on_player_dash_changed.bind(player))
	player.visual_event.connect(_on_player_visual_event.bind(player))
	_entities.add_child(player)
	_players[peer_id] = player
	if peer_id == Session.local_peer_id() or _player == null:
		_player = player


func get_player() -> Player:
	return _player


## Every uncollected gem or crystal, in Level's local space — what the 'dark'
## overlay draws a glow dot on top of so the modifier costs navigation, not
## collection outright.
func _dark_glow_positions() -> Array:
	var out: Array = []
	for child in _entities.get_children():
		if child is Gem or child is DashCrystal:
			out.append((child as Node2D).position)
	return out


func get_players() -> Array[Player]:
	var out: Array[Player] = []
	for player: Player in _players.values():
		out.append(player)
	return out


# --------------------------------------------------------------- events ---

func _on_gem_collected(gem: Gem, player: Player) -> void:
	if Session.is_active() and not Session.is_host():
		if player.locally_controlled:
			var node_name := str(gem.name)
			# Collection is immediate on the machine that touched it. The host
			# trusts that event and relays the same removal to everyone else.
			_collect_gem(gem)
			Session.publish_player_event("GEM_TOUCHED", {"node": node_name})
		return
	_collect_gem(gem)
	if Session.is_active():
		Session.publish_world_event("GEM_TAKEN", {
			"node": str(gem.name),
			"secret": gem.secret,
		})


func _collect_gem(gem: Gem) -> void:
	if not is_instance_valid(gem) or gem.is_queued_for_deletion():
		return
	var at := fx.to_local(gem.global_position)
	if gem.secret:
		# Deliberately outside gems_total: the door fills from the gems the
		# room asks for, and a secret the player has not found yet must never
		# leave that bar looking incomplete.
		secrets_taken += 1
		Save.take_secret(index)
		Audio.play("gem", 1.35)
		fx.emit(at, 14, Palette.PURPLE, 90.0, Vector2.ZERO, TAU, 0.5, 200.0)
		fx.popup(at, Lang.t("secret.found"), Palette.PURPLE, 1.1)
	else:
		gems_taken += 1
		Save.add_gem()
		Audio.play("gem", 1.0 + gems_taken * 0.03)
		fx.emit(at, 10, Palette.GOLD, 80.0, Vector2.ZERO, TAU, 0.4, 180.0)
		fx.popup(at, "+1", Palette.GOLD)
		_update_door_charge()
	gem.queue_free()


## A ground pound clears the ground it lands on: blocks give way, and anything
## standing right there is squashed. The player does not know what is nearby,
## so the level answers for it.
func _on_player_pounded(at: Vector2, player: Player) -> void:
	if ghost_enabled and player == get_player() and last_recording.size() < GhostStore.MAX_SAMPLES:
		# The nearest 20Hz sample not yet appended — up to one tick (50ms) off
		# the real landing, which a flash of squash never shows.
		last_recording_pounds.append(last_recording.size())
	if Session.is_active() and not player.locally_controlled:
		return
	# A bombado landing is the same event, twice the crater. The reach is asked
	# of the player rather than read off the constant, because only the player
	# knows which body just hit the floor.
	var reach := player.pound_reach()
	var buff := player.is_buff()
	shake(9.0 if buff else 5.0)
	fx.emit(fx.to_local(at), 30 if buff else 16, Palette.CYAN,
		170.0 if buff else 110.0, Vector2.UP, PI, 0.4, 220.0)

	var hits: Array[Dictionary] = []
	for child in _entities.get_children():
		var distance := at.distance_to((child as Node2D).global_position)
		if child is Breakable and distance <= reach + 6.0:
			(child as Breakable).shatter()
			hits.append({"node": str(child.name), "action": "BREAK"})
		elif child is Slime and distance <= reach:
			(child as Slime).die()
			hits.append({"node": str(child.name), "action": "DEFEAT"})
		elif child is Bat and distance <= reach:
			(child as Bat).die()
			hits.append({"node": str(child.name), "action": "DEFEAT"})
		elif child is ShieldEnemy and distance <= reach:
			(child as ShieldEnemy).die()
			hits.append({"node": str(child.name), "action": "DEFEAT"})
		# ElasticSlime is deliberately absent: it is a route as much as a
		# hazard, and a pound that erased it would erase the way across.
	if Session.is_client() and player.locally_controlled:
		Session.publish_player_event("POUND", {
			"x": at.x,
			"y": at.y,
			"hits": hits,
		})


## Combo colours read as a temperature: cyan is nothing special yet, gold is a
## real chain, white is rare. The number is what teaches the system — words
## would repeat what the codex already says.
func _on_combo_changed(count: int, _verb: int, player: Player) -> void:
	var color := Palette.CYAN
	if count > 6:
		color = Palette.WHITE
	elif count >= 4:
		color = Palette.GOLD
	fx.popup(fx.to_local(player.global_position + Vector2(0, -14.0)),
		"x%d" % count, color, 0.5)


func _on_combo_ended(count: int) -> void:
	score += 100 * count * count
	best_combo = maxi(best_combo, count)


## One boolean, every gate reads it. A gate closing on top of someone kills
## them rather than trapping them or getting pushed aside by move_and_slide()
## in whatever direction the overlap happens to resolve — a telegraphed hazard
## beats an untelegraphed shove.
const LASER_FREEZE := 4.0


func _on_switch_pressed(player: Player) -> void:
	if Session.is_active():
		if Session.is_client():
			if player.locally_controlled:
				_apply_switch_state(not switch_state)
				Session.publish_player_event("SWITCH_PRESSED")
			return
		# Remote host puppets use their explicit client event; physical overlap
		# would otherwise flip the same switch twice.
		if player.client_authority:
			return
	toggle_switch()


func toggle_switch() -> void:
	_apply_switch_state(not switch_state)
	if Session.is_active() and Session.is_host():
		Session.publish_world_event("SWITCH_STATE", {"state": switch_state})


# ------------------------------------------------------------------- clone ---

## One-shot: touching the pad a second time (a clone standing on it counts as
## touching nothing, since only the player triggers this signal) never
## restarts a recording already running.
func _on_record_pad_touched(pad: RecordPad) -> void:
	if _recording or not is_instance_valid(pad):
		return
	_recording = true
	_record_t = 0.0
	_record_buffer = PackedVector2Array()
	pad.queue_free()


func _spawn_clone() -> void:
	if _record_buffer.is_empty():
		return
	var clone := Clone.new()
	clone.setup(_record_buffer)
	_entities.add_child(clone)


## Sensors hold switch_state the way a step-12 button toggles it — the only
## difference is a sensor's value is read fresh every frame instead of
## flipped once on a press, so a gate it opens closes again the instant
## nothing is left standing on it.
func _update_sensors() -> void:
	if _sensors.is_empty():
		return
	var any_pressed := false
	for sensor: Sensor in _sensors:
		var pressed := _weight_on(sensor.global_position)
		sensor.set_pressed(pressed)
		any_pressed = any_pressed or pressed
	if any_pressed != switch_state:
		_apply_switch_state(any_pressed)


func _weight_on(center: Vector2) -> bool:
	var half := Vector2(4.0, 4.0)
	var body_half := Vector2(Player.WIDTH, Player.HEIGHT) * 0.5
	for player: Player in get_players():
		if player.alive and _aabb_overlap(player.global_position, body_half, center, half):
			return true
	for child in _entities.get_children():
		if child is Clone and _aabb_overlap((child as Node2D).global_position, body_half, center, half):
			return true
	return false


func _aabb_overlap(pos_a: Vector2, half_a: Vector2, pos_b: Vector2, half_b: Vector2) -> bool:
	var d := pos_a - pos_b
	return absf(d.x) < half_a.x + half_b.x and absf(d.y) < half_a.y + half_b.y


func _apply_switch_state(value: bool) -> void:
	switch_state = value
	Audio.play("switch")
	shake(2.0)

	for laser: Laser in _lasers:
		laser.freeze(LASER_FREEZE)
	for gate: GateBlock in _gates:
		var now_solid := gate.compute_solid(switch_state)
		if now_solid and not gate.solid:
			for player: Player in get_players():
				if player.alive and gate.overlaps_player(player):
					player.kill()
		gate.set_solid(now_solid)
	for pad: SwitchPad in _switches:
		pad.refresh(switch_state)


## A block is intangible for as long as anyone is dashing, and turns solid
## again the instant nobody is — not when this one player's dash ends, since a
## second player could still be inside it.
func _on_player_dash_changed(active: bool, player: Player) -> void:
	if active:
		_dashing[player.peer_id] = true
	else:
		_dashing.erase(player.peer_id)

	var anyone_dashing := not _dashing.is_empty()
	for block: PhaseBlock in _phase_blocks:
		block.set_solid(not anyone_dashing)
	if not anyone_dashing:
		for other: Player in get_players():
			_eject_from_phase(other)


## Bombado (doc/bombadao). The heavy weather belongs to the screen the local
## player is looking at, so a remote peer turning changes nothing here — their
## own machine dims their own room. Built lazily and freed on the way out
## rather than kept hidden, because a room whose player never transforms
## should not be paying for an overlay that redraws every frame.
func _on_player_buff_changed(active: bool, player: Player) -> void:
	if player != _player:
		return
	if active:
		if _buff_aura == null:
			_buff_aura = BuffAura.new()
			_buff_aura.player = player
			add_child(_buff_aura)
			# Between the terrain and the entities, not on top of everything.
			# Every layer here shares z_index 0 and is ordered by the tree, so
			# one move_child() is the whole of it. Drawn above the players the
			# warm veil desaturates them — the room is supposed to look heavy,
			# not the hero — and the particles Fx draws stay above it either
			# way, since Fx is added after _entities.
			move_child(_buff_aura, _entities.get_index())
		_buff_aura.set_active(true)
		_buff_rumble = BUFF_RUMBLE
	elif _buff_aura != null:
		# fade_out() frees the node once it has faded, so the aura is never
		# yanked off screen mid-frame.
		_buff_aura.set_active(false)
		_buff_aura = null


func _tick_buff_weather(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_buff():
		return
	_buff_rumble -= delta
	if _buff_rumble <= 0.0:
		_buff_rumble = BUFF_RUMBLE
		shake(BUFF_RUMBLE_SHAKE)


## The dash ended inside a block. Push along whatever direction the player was
## still moving until they clear every block, at most 32 steps — if that is
## not enough the room's geometry is wrong, and getting stuck forever is worse
## than a death with an obvious cause.
func _eject_from_phase(player: Player) -> void:
	if not player.alive or _phase_blocks.is_empty():
		return
	var dir := player.velocity.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2(player.facing, 0)
	for step in 32:
		if not _overlaps_any_phase(player.global_position):
			return
		player.global_position += dir * 2.0
	player.kill()


func _overlaps_any_phase(pos: Vector2) -> bool:
	for block: PhaseBlock in _phase_blocks:
		if block.contains(pos):
			return true
	return false


func _on_block_broken(at: Vector2, block: Breakable) -> void:
	Audio.play_varied("break")
	fx.emit(fx.to_local(at), 12, Palette.GOLD, 95.0, Vector2.ZERO, TAU, 0.45, 260.0)
	_report_entity_action("BREAK", block)


func _on_bat_squashed(at: Vector2, bat: Bat) -> void:
	fx.emit(fx.to_local(at), 12, Palette.PURPLE, 90.0, Vector2.UP, PI, 0.4, 260.0)
	shake(2.0)
	_report_entity_action("DEFEAT", bat)


func _on_elastic_bounced(at: Vector2, elastic: ElasticSlime) -> void:
	fx.emit(fx.to_local(at), 8, Palette.GOLD, 70.0, Vector2.UP, PI, 0.3, 220.0)
	shake(1.5)
	_report_entity_action("ELASTIC", elastic)


func _on_slime_squashed(at: Vector2, mob: Node2D) -> void:
	fx.emit(fx.to_local(at), 12, Palette.GREEN, 90.0, Vector2.UP, PI, 0.4, 260.0)
	shake(2.0)
	_report_entity_action("DEFEAT", mob)


func _on_spring_bounced(_at: Vector2, spring: Spring) -> void:
	_report_entity_action("SPRING", spring)


func _on_crystal_activated(_at: Vector2, crystal: DashCrystal) -> void:
	_report_entity_action("CRYSTAL", crystal)


func _on_crumble_state_changed(_at: Vector2, state: int, time_left: float, crumble: Crumble) -> void:
	if state == 1:
		_report_entity_action("CRUMBLE", crumble, {"time_left": time_left})


func _on_ferry_state_changed(_at: Vector2, state: int, time: float, direction: int,
		carrying: bool, carry: float, ferry: FerryBat) -> void:
	_report_entity_action("FERRY", ferry, {
		"state": state,
		"time": time,
		"direction": direction,
		"carrying": carrying,
		"carry": carry,
	})


func _report_entity_action(action: String, entity: Node, extra: Dictionary = {}) -> void:
	if not Session.is_active() or not is_instance_valid(entity):
		return
	var payload: Dictionary = {"action": action, "node": str(entity.name)}
	for key: Variant in extra:
		payload[key] = extra[key]
	if Session.is_host():
		Session.publish_world_event("ENTITY_ACTION", payload)
	else:
		Session.publish_player_event("ENTITY_ACTION", payload)


func _update_door_charge() -> void:
	if _door == null:
		return
	_door.charge = 1.0 if gems_total == 0 else float(gems_taken) / float(gems_total)


func _on_door_entered(player: Player) -> void:
	if finished:
		return
	if Session.is_active() and not Session.is_host():
		# A client renders every player, but may only report its own arrival.
		# Without this guard, the host puppet touching the door on the client
		# marks that client as ready and lets the host advance prematurely.
		if not player.locally_controlled:
			return
		player.enter_door(_door.global_position)
		Session.publish_player_event("DOOR_ENTERED")
		return
	if Session.is_active():
		if _door_arrivals.has(player.peer_id):
			return
		_door_arrivals[player.peer_id] = true
		player.enter_door(_door.global_position)
		Session.publish_world_event("DOOR_ENTERED", {"peer_id": player.peer_id})
		if not competitive and not _all_players_entered_door():
			return
	else:
		_door_arrivals[player.peer_id] = true
	_finish_room()
	if Session.is_active():
		Session.publish_world_event("ROOM_COMPLETED", {})


func _all_players_entered_door() -> bool:
	if _players.is_empty():
		return false
	for peer_id: int in _players.keys():
		if not _door_arrivals.has(peer_id):
			return false
	return true


func _finish_room() -> void:
	if finished:
		return
	finished = true
	running = false
	for player: Player in _players.values():
		if Session.is_client() or competitive or _door_arrivals.has(player.peer_id):
			player.enter_door(_door.global_position)
	if _lava != null:
		_lava.stop()
	Audio.play("door")
	fx.emit(_door.position, 24, Palette.PURPLE, 90.0, Vector2.ZERO, TAU, 0.7, 90.0)
	completed.emit(time, gems_taken, gems_total, score, best_combo)


func _on_player_died(player: Player) -> void:
	if finished or _pending_respawns.has(player.peer_id):
		return
	_pending_respawns[player.peer_id] = true
	deaths += 1
	_door_arrivals.erase(player.peer_id)
	_on_player_dash_changed(false, player)
	if _door != null:
		_door.reset_player(player.peer_id)
	if Session.is_active():
		if Session.is_host():
			Session.publish_world_event("PLAYER_DIED", {"peer_id": player.peer_id})
		elif player.locally_controlled:
			Session.publish_player_event("PLAYER_DIED")
	shake(4.0)
	player_died.emit()
	if not Session.is_active() or Session.is_host():
		Save.add_death()
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	_pending_respawns.erase(player.peer_id)
	if is_inside_tree() and not finished:
		if Session.is_active():
			player.respawn(_spawn)
		else:
			restart()


func _on_network_snapshot(snapshot: Dictionary) -> void:
	if not Session.is_client() or finished:
		return
	time = float(snapshot.get("time", time))
	gems_taken = int(snapshot.get("gems_taken", gems_taken))
	gems_total = int(snapshot.get("gems_total", gems_total))
	deaths = int(snapshot.get("deaths", deaths))
	for player_state: Dictionary in snapshot.get("players", []):
		var peer_id := int(player_state.get("peer_id", -1))
		var player: Player = _players.get(peer_id)
		if player != null:
			player.apply_network_snapshot(player_state)
	_apply_entity_snapshot(snapshot.get("entities", []))
	_update_door_charge()


func _on_client_player_state(peer_id: int, snapshot: Dictionary) -> void:
	if not Session.is_host() or finished:
		return
	var player: Player = _players.get(peer_id)
	if player != null:
		player.apply_client_state(snapshot)


func _on_player_visual_event(kind: String, fx_position: Vector2, direction: Vector2,
		player: Player) -> void:
	# Bombado needs the room itself to move, and this signal is the one channel
	# a player already has for "something happened over here". Handled above
	# the network guard on purpose: that guard returns early offline, and the
	# shake has to land in single player too.
	if player == _player:
		match kind:
			"buff_rise":
				shake(3.0)
			"buff_ready":
				shake(12.0)
			"buff_pose":
				shake(2.0)
	if not Session.is_active():
		return
	var payload := {
		"peer_id": player.peer_id,
		"kind": kind,
		"x": fx_position.x,
		"y": fx_position.y,
		"dx": direction.x,
		"dy": direction.y,
	}
	if Session.is_host():
		Session.publish_world_event("PLAYER_FX", payload)
	elif player.locally_controlled:
		Session.publish_player_event("FX", payload)


func _on_client_player_event(peer_id: int, kind: String, payload: Dictionary) -> void:
	if not Session.is_host() or finished:
		return
	var player: Player = _players.get(peer_id)
	if player == null:
		return
	if kind == "DOOR_ENTERED":
		_on_door_entered(player)
		return
	if kind == "GEM_TOUCHED":
		var gem := _entities.get_node_or_null(NodePath(str(payload.get("node", ""))))
		if gem is Gem:
			_on_gem_collected(gem as Gem, player)
		return
	if kind == "POUND":
		var raw_hits: Variant = payload.get("hits", [])
		if raw_hits is Array:
			for raw_hit: Variant in raw_hits:
				if raw_hit is Dictionary:
					_apply_client_entity_action(raw_hit)
		return
	if kind == "SWITCH_PRESSED":
		toggle_switch()
		return
	if kind == "PLAYER_DIED":
		if not _pending_respawns.has(peer_id):
			player.apply_network_death()
			_on_player_died(player)
		return
	if kind == "ENTITY_ACTION":
		_apply_client_entity_action(payload)
		var action := str(payload.get("action", ""))
		if action != "DEFEAT" and action != "BREAK":
			Session.publish_world_event("ENTITY_ACTION", payload)
		return
	if kind != "FX":
		return
	var event := payload.duplicate(true)
	event["peer_id"] = peer_id
	_play_player_fx(str(event.get("kind", "")), event)
	Session.publish_world_event("PLAYER_FX", event)


func _apply_client_entity_action(payload: Dictionary) -> void:
	var node_name := str(payload.get("node", ""))
	var entity := _entities.get_node_or_null(NodePath(node_name))
	if entity == null:
		return
	match str(payload.get("action", "")):
		"DEFEAT":
			if entity is Slime:
				(entity as Slime).die()
			elif entity is Bat:
				(entity as Bat).die()
			elif entity is ShieldEnemy:
				(entity as ShieldEnemy).die()
		"BREAK":
			if entity is Breakable:
				(entity as Breakable).shatter()
		"ELASTIC":
			if entity is ElasticSlime:
				(entity as ElasticSlime).network_bounce()
		"SPRING":
			if entity is Spring:
				(entity as Spring).network_trigger()
		"CRYSTAL":
			if entity is DashCrystal:
				(entity as DashCrystal).network_activate()
		"CRUMBLE":
			if entity is Crumble:
				(entity as Crumble).network_begin_break(float(payload.get("time_left", 0.0)))
		"FERRY":
			if entity is FerryBat:
				(entity as FerryBat).apply_network_state(payload)


func _apply_network_entity_action(payload: Dictionary) -> void:
	var node_name := str(payload.get("node", ""))
	var entity := _entities.get_node_or_null(NodePath(node_name))
	if entity == null:
		return
	var action := str(payload.get("action", ""))
	_play_network_entity_action_fx(action, entity)
	match action:
		"DEFEAT":
			if entity.has_method("apply_network_defeat"):
				entity.call("apply_network_defeat")
		"BREAK":
			if entity is Breakable:
				(entity as Breakable).apply_network_break()
		"ELASTIC":
			if entity is ElasticSlime:
				(entity as ElasticSlime).network_bounce()
		"SPRING":
			if entity is Spring:
				(entity as Spring).network_trigger()
		"CRYSTAL":
			if entity is DashCrystal:
				(entity as DashCrystal).network_activate()
		"CRUMBLE":
			if entity is Crumble:
				(entity as Crumble).network_begin_break(float(payload.get("time_left", 0.0)))
		"FERRY":
			if entity is FerryBat:
				(entity as FerryBat).apply_network_state(payload)


func _play_network_entity_action_fx(action: String, entity: Node) -> void:
	if fx == null or not (entity is Node2D):
		return
	var at := fx.to_local((entity as Node2D).global_position)
	match action:
		"BREAK":
			fx.emit(at, 12, Palette.GOLD, 95.0, Vector2.ZERO, TAU, 0.45, 260.0)
		"DEFEAT":
			var color := Palette.PURPLE if entity is Bat else Palette.GREEN
			fx.emit(at, 12, color, 90.0, Vector2.UP, PI, 0.4, 260.0)
		"ELASTIC":
			fx.emit(at, 8, Palette.GOLD, 70.0, Vector2.UP, PI, 0.3, 220.0)


func _play_player_fx(kind: String, payload: Dictionary) -> void:
	var at := Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0)))
	var direction := Vector2(float(payload.get("dx", 0.0)), float(payload.get("dy", 0.0)))
	var player: Player = _players.get(int(payload.get("peer_id", -1)))
	var color := Player.player_color(player.color_index) if player != null else Palette.CYAN
	var dark := color.darkened(0.45)
	if player != null:
		player.network_action(kind, direction)
	match kind:
		"dash":
			fx.emit(at, 8, color, 90.0, -direction, 0.9, 0.3, 240.0)
		"jump":
			fx.dust(at, dark, 6)
		"wall_jump":
			fx.emit(at, 6, color, 70.0, direction, 1.2, 0.3, 200.0)
		"land":
			fx.dust(at, dark, 7)
		"pound_land":
			fx.dust(at, color, 14)
		"buff_rise":
			fx.emit(at, 2, Palette.FRAME, 130.0, direction, 1.5, 0.45, 220.0)
		"buff_ready":
			fx.emit(at, 20, color, 170.0, direction, PI, 0.5, 240.0)
			fx.dust(at, Palette.FRAME, 12)
		"buff_pose":
			fx.dust(at, color, 6)
		"death":
			fx.emit(at, 26, color, 130.0, Vector2.ZERO, TAU, 0.6, 300.0)
			fx.emit(at, 10, Palette.WHITE, 90.0, Vector2.ZERO, TAU, 0.4, 260.0)


func _observe_host_world() -> void:
	# Local players validate contact on their own machine. Entity state still
	# receives frequent host snapshots, but hazards and mobs keep processing so
	# a client never has to wait a network round trip before a collision counts.
	pass


func _apply_entity_snapshot(states: Array) -> void:
	var live: Dictionary = {}
	for state: Dictionary in states:
		var node_name := str(state.get("node", ""))
		live[node_name] = true
		var child := _entities.get_node_or_null(NodePath(node_name)) as Node2D
		if child == null:
			continue
		child.position = Vector2(float(state.get("x", child.position.x)),
			float(state.get("y", child.position.y)))
		child.visible = bool(state.get("visible", child.visible))
		if child.has_method("apply_network_state"):
			child.call("apply_network_state", state)
		child.process_mode = Node.PROCESS_MODE_INHERIT
	for child: Node2D in _entities.get_children():
		if not (child is Player) and not live.has(str(child.name)):
			child.queue_free()


func _on_network_world_event(event: Dictionary) -> void:
	if not Session.is_client() or finished:
		return
	var payload: Dictionary = event.get("payload", {})
	match str(event.get("kind", "")):
		"GEM_TAKEN":
			var node := _entities.get_node_or_null(NodePath(str(payload.get("node", ""))))
			if node is Gem:
				_collect_gem(node as Gem)
		"PLAYER_FX":
			if int(payload.get("peer_id", -1)) != Session.local_peer_id():
				_play_player_fx(str(payload.get("kind", "")), payload)
		"PLAYER_DIED":
			var dead_peer_id := int(payload.get("peer_id", -1))
			if dead_peer_id != Session.local_peer_id():
				var player: Player = _players.get(dead_peer_id)
				if player != null:
					player.apply_network_death()
		"ENTITY_ACTION":
			_apply_network_entity_action(payload)
		"DOOR_ENTERED":
			var peer_id := int(payload.get("peer_id", -1))
			var player: Player = _players.get(peer_id)
			if player != null and _door != null:
				player.enter_door(_door.global_position)
		"SWITCH_STATE":
			_apply_switch_state(bool(payload.get("state", false)))
		"ROOM_COMPLETED":
			_finish_room()


func _on_roster_changed(roster: Dictionary) -> void:
	if not Session.is_active():
		return
	for peer_id: int in _players.keys():
		if roster.has(peer_id):
			continue
		var player: Player = _players[peer_id]
		player.queue_free()
		_players.erase(peer_id)
		_door_arrivals.erase(peer_id)
		_pending_respawns.erase(peer_id)
	for peer_id: int in roster.keys():
		if _players.has(peer_id):
			continue
		_spawn_player(peer_id)


## Rebuild everything that can be interacted with. Terrain and collision are
## untouched — they never change.
func restart() -> void:
	finished = false
	score = 0
	best_combo = 0
	_door_arrivals = {}
	_snapshot_time = 0.0
	for child in _entities.get_children():
		# Detach first so a dying gem or slime cannot fire one last signal.
		_entities.remove_child(child)
		child.queue_free()
	fx.clear()
	_door = null
	_lava = null
	_spawn_entities()
	# _darkness lives outside _entities and survives the wipe above; it just
	# needs pointing at the player restart() rebuilt.
	if _darkness != null:
		_darkness.player = _player
	# The aura lives outside _entities too, but unlike darkness it belongs to a
	# player who no longer exists — the wipe above freed the body that was
	# bombado. Drop it outright rather than repointing it.
	if _buff_aura != null:
		_buff_aura.set_active(false)
		_buff_aura = null
	# The recording is of the attempt that just ended, not the accumulated
	# time since the room first opened — a fresh attempt starts a fresh trace.
	last_recording = PackedVector2Array()
	last_recording_pounds = PackedInt32Array()
	_ghost_sample_t = 0.0
	if _ghost_player != null:
		_ghost_player.restart()
	running = true
