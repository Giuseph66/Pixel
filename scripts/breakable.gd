class_name Breakable
extends Node2D

## Ground that only a ground pound gets through. It stays broken for the rest
## of the attempt — a block that grew back would turn a route decision into a
## waiting game, which is what the timed blocks are already for.

signal broken(at: Vector2)

var _body: StaticBody2D
var _sprite: Sprite2D
var _gone := false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("breakable")
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


func shatter() -> void:
	if _gone:
		return
	_gone = true
	broken.emit(global_position)
	for child in _body.get_children():
		(child as CollisionShape2D).set_deferred("disabled", true)
	_sprite.visible = false
	# Freed a frame later so the signal handler can still read the position.
	queue_free()


func is_gone() -> bool:
	return _gone


func apply_network_break() -> void:
	if _gone:
		return
	_gone = true
	for child in _body.get_children():
		(child as CollisionShape2D).set_deferred("disabled", true)
	_sprite.visible = false
	queue_free()
