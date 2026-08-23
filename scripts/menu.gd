class_name Menu
extends Node2D

## Shared skeleton for every screen that is a list of choices.
## Subclasses override draw_header() to put something above the list.

signal chosen(id: String)
signal cancelled

const SCREEN := Vector2(480, 270)

var title := ""
var subtitle := ""
var footer := ""
var items: Array = []           # [{ "id": String, "label": String, "value": String }]
var cursor := 0
var allow_cancel := false
var opaque := true              # false lets the paused game show through
var list_top := 150.0
var line_height := 14.0

var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_time += delta
	_handle_input()
	queue_redraw()


func _handle_input() -> void:
	if items.is_empty():
		return
	if Input.is_action_just_pressed("p_up"):
		_move(-1)
	elif Input.is_action_just_pressed("p_down"):
		_move(1)
	elif Input.is_action_just_pressed("p_accept"):
		Audio.play("menu_select")
		chosen.emit(items[cursor]["id"])
	elif allow_cancel and Input.is_action_just_pressed("p_cancel"):
		Audio.play("menu_back")
		cancelled.emit()


func _move(step: int) -> void:
	cursor = wrapi(cursor + step, 0, items.size())
	Audio.play("menu_move")


func set_item_value(id: String, value: String) -> void:
	for item in items:
		if item["id"] == id:
			item["value"] = value
			return


# ------------------------------------------------------------------ draw ---

func _draw() -> void:
	if opaque:
		draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Palette.BG)
		draw_backdrop()
	else:
		var dim := Palette.BG
		dim.a = 0.78
		draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), dim)
	draw_header()

	if not title.is_empty():
		PixelFont.draw_text_centered_shadow(self, title, SCREEN.x * 0.5, 34.0,
			Palette.WHITE, Palette.MAGENTA_DARK, 3)
	if not subtitle.is_empty():
		PixelFont.draw_text_centered(self, subtitle, SCREEN.x * 0.5, 62.0, Palette.GREY, 1)

	for i in items.size():
		_draw_item(i)

	if not footer.is_empty():
		PixelFont.draw_text_centered(self, footer, SCREEN.x * 0.5, SCREEN.y - 16.0,
			Palette.GREY_DARK, 1)


func _draw_item(i: int) -> void:
	var item: Dictionary = items[i]
	var y := list_top + i * line_height
	var selected := i == cursor
	var label: String = item["label"]
	if item.has("value") and not str(item["value"]).is_empty():
		label += "  " + str(item["value"])

	var color := Palette.WHITE if selected else Palette.GREY_DARK
	PixelFont.draw_text_centered(self, label, SCREEN.x * 0.5, y, color, 2)

	if selected:
		var size := PixelFont.measure(label, 2)
		# The marker breathes so the eye finds it instantly.
		var nudge := 0.0 if fmod(_time, 0.7) < 0.35 else 1.0
		var x := SCREEN.x * 0.5 - size.x * 0.5 - 14.0 - nudge
		PixelFont.draw_text(self, ">", Vector2(roundf(x), y), Palette.MAGENTA, 2)


## A faint moving field of dots, so no screen is ever dead flat.
func draw_backdrop() -> void:
	for i in 40:
		var seed_x := float((i * 7919) % 480)
		var drift := fmod(seed_x + _time * (6.0 + float(i % 5) * 2.0), 480.0)
		var y := float((i * 6151) % 270)
		draw_rect(Rect2(roundf(drift), roundf(y), 1, 1), Palette.BG_SOFT)


## Hook for subclasses.
func draw_header() -> void:
	pass
