class_name Crumble

extends Node2D

## Ground that will not wait. Stand on it and it shakes, drops out from under
## you, then rebuilds itself a couple of seconds later — so a bridge of these
## over a spike pit is a room that punishes hesitating rather than mistiming.

const BREAK_DELAY := 0.38
const GONE := 2.0

var _sprite: Sprite2D
var _body: StaticBody2D
var _sensor: Area2D
var _timer := 0.0
var _state := 0                  # 0 solid, 1 breaking, 2 gone


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("crumble")
	add_child(_sprite)

	_body = StaticBody2D.new()
	_body.collision_layer = 2
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 8)
	shape.shape = rect
	_body.add_child(shape)
	add_child(_body)

	# A thin strip along the top edge: only weight from above sets it off.
	_sensor = Area2D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 1
	var sense := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 3)
	sense.shape = box
	sense.position.y = -4.0
	_sensor.add_child(sense)
	add_child(_sensor)


func _physics_process(delta: float) -> void:
	match _state:
		0:
			for body in _sensor.get_overlapping_bodies():
				if body is Player and (body as Player).alive:
					_state = 1
					_timer = BREAK_DELAY
					_sprite.texture = PixelArt.tex("crumble_cracked")
					Audio.play("land")
					break
		1:
			_timer -= delta
			# Shiver on whole pixels while it holds on.
			_sprite.position.x = 0.0 if fmod(_timer * 22.0, 2.0) < 1.0 else 1.0
			if _timer <= 0.0:
				_fall()
		2:
			_timer -= delta
			if _timer <= 0.0:
				_restore()


func _fall() -> void:
	_state = 2
	_timer = GONE
	_sprite.position.x = 0.0
	_sprite.visible = false
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	for child in _body.get_children():
		(child as CollisionShape2D).set_deferred("disabled", true)


func _restore() -> void:
	_state = 0
	_sprite.visible = true
	_sprite.texture = PixelArt.tex("crumble")
	_body.process_mode = Node.PROCESS_MODE_INHERIT
	for child in _body.get_children():
		(child as CollisionShape2D).set_deferred("disabled", false)
