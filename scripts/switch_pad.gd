class_name SwitchPad
extends Area2D

## A button the player walks over. It has no state of its own — Level owns
## switch_state, and every pad in the room flips the same one, which is what
## makes "walk back onto a switch" a real move rather than a dead end.

signal pressed

var _armed := true
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("switch_off")
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(7, 7)
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## One trigger per visit. Without the exit-armed lock, standing on the pad
## would flip every gate in the room sixty times a second.
func _on_body_entered(body: Node2D) -> void:
	if body is Player and _armed:
		_armed = false
		pressed.emit()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_armed = true


func refresh(state: bool) -> void:
	_sprite.texture = PixelArt.tex("switch_on" if state else "switch_off")
