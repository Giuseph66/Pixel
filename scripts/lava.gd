class_name Lava
extends Node2D

## Rising tide that kills on contact. Constant rise speed throughout the room.

const RISE := 9.0
const RISE_MAX := 26.0

var speed_scale := 1.0
var _player: Player
var _surface := 0.0  # pixel Y position
var _initial_y := 0.0


func _ready() -> void:
	_surface = position.y
	_initial_y = position.y
	z_index = 10


func _physics_process(delta: float) -> void:
	_surface -= RISE * speed_scale * clampf(speed_scale, 1.0, 2.2 / RISE) * delta
	queue_redraw()

	if _player != null and _player.alive and not _player.frozen:
		if _player.global_position.y + Player.HEIGHT * 0.5 > _surface:
			_player.kill()


func _draw() -> void:
	var y := _surface - position.y
	var width := 480.0
	var height := position.y + 270.0 - _surface

	draw_rect(Rect2(0, y, width, height), Palette.PURPLE)
	draw_line(Vector2(0, y), Vector2(width, y), Palette.GOLD, 1.0)
	if fmod(_surface, 1.0) < 0.5:
		draw_line(Vector2(0, y - 1.0), Vector2(width, y - 1.0), Palette.WHITE, 1.0)


func reset() -> void:
	_surface = _initial_y
	queue_redraw()
