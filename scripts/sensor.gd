class_name Sensor
extends Node2D

## Step 24 — clone fantasma. A pressure plate rather than a button: Level
## polls _weight_on() against it every frame and calls set_pressed() with
## whatever it finds, so the sprite and the switch_state it drives both read
## as "something is standing here right now" instead of "something pressed
## this once." The player and a Clone both count — that is the whole point
## of the tile ("SEU OU DE OUTRO" in the codex).

var pressed := false
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.tex("sensor_off")
	add_child(_sprite)


func set_pressed(value: bool) -> void:
	if value == pressed:
		return
	pressed = value
	_sprite.texture = PixelArt.tex("sensor_on" if value else "sensor_off")
