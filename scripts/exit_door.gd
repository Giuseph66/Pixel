class_name ExitDoor
extends Area2D

## The way out. Its interior is drawn every frame rather than being a sprite,
## so the swirl inside can react to how many gems are still on the level.

signal entered

const FRAME_W := 12
const FRAME_H := 16

var charge := 0.0            # 0..1, how complete the level is
var _time := 0.0
var _used := false
var _canvas: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	var sprite := Sprite2D.new()
	sprite.texture = PixelArt.tex("door")
	add_child(sprite)

	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_interior)
	add_child(_canvas)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 12)
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()


## Six drifting pixels inside the frame, brighter as the level fills up.
func _draw_interior() -> void:
	var glow := Palette.PURPLE.lerp(Palette.WHITE, 0.25 + charge * 0.55)
	for i in 6:
		var phase := _time * 1.6 + i * (TAU / 6.0)
		var radius := 1.5 + 1.5 * sin(_time * 2.0 + i)
		var p := Vector2(roundf(cos(phase) * radius), roundf(sin(phase * 0.8) * (radius + 1.5)))
		_canvas.draw_rect(Rect2(p.x, p.y, 1, 1), glow)

	# A pulse along the arch when every gem has been found.
	if charge >= 1.0:
		var t := fmod(_time * 1.2, 1.0)
		var y := lerpf(6.0, -6.0, t)
		_canvas.draw_rect(Rect2(-3, roundf(y), 6, 1), Palette.WHITE)


func _on_body_entered(body: Node2D) -> void:
	if _used:
		return
	if body is Player and (body as Player).alive:
		_used = true
		entered.emit()
