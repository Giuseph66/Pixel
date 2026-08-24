class_name RetractSpike
extends Node2D

## Spike that retracts and rises on a beat, blocking the path periodically.
## Same cycle as timed blocks, so the player sees a familiar rhythm.

const PERIOD := 1.15            # same as TimedBlock, on purpose
const WARN := 0.3               # blink this long before rising

var speed_scale := 1.0          # scaled by level intensity
var _time := 0.0
var _area: Area2D
var _sprite: Sprite2D
var _frame := 0


func _ready() -> void:
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1
	add_child(_area)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8.0, 8.0)
	shape.shape = rect
	shape.position = Vector2(4.0, 4.0)
	_area.add_child(shape)

	_area.area_entered.connect(_on_player_touched)
	_area.monitoring = false  # starts retracted

	_sprite = Sprite2D.new()
	add_child(_sprite)


func setup(down: bool) -> void:
	_frame = 1 if down else 0


func _physics_process(delta: float) -> void:
	_time = fmod(_time + delta * speed_scale, PERIOD)

	# Recolhido vs subindo
	var is_up := _time >= (PERIOD - WARN)

	_area.monitoring = is_up  # só mata quando subido

	# Pisca durante aviso
	if is_up and fmod(_time, 0.1) < 0.05:
		_sprite.texture = PixelArt.tex("spike_low")
	elif is_up:
		_sprite.texture = PixelArt.tex("spike_up")
	else:
		_sprite.texture = PixelArt.tex("spike_low")


func _on_player_touched(area: Area2D) -> void:
	if area.get_parent() is Player:
		(area.get_parent() as Player).kill()
