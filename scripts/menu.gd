class_name Menu
extends Node2D

## Shared skeleton for every screen that is a list of choices.
## Subclasses override draw_header() to put something above the list.

signal chosen(id: String)
signal cancelled

const SCREEN := Vector2(480, 270)

const ITEM_SCALE := 2
## A glyph is PixelFont.H tall, so an entry is exactly this many pixels of ink.
## line_height has to stay clear of it or consecutive rows touch.
const ITEM_HEIGHT := PixelFont.H * ITEM_SCALE
const CURSOR_GAP := 14.0

var title := ""
var subtitle := ""
var footer := ""
var items: Array = []           # [{ "id": String, "label": String, "value": String }]
var cursor := 0
var allow_cancel := false
var opaque := true              # false lets the paused game show through
var list_top := 150.0
var list_width := 260.0         # backdrop width behind the (non-opaque) list
var line_height := 20.0

## Set by TitleScreen and PauseMenu: draws the book icon top-right and lets
## p_codex emit chosen("codex") from anywhere on the screen, not just from a
## row in the list. Screens where the book makes no sense (options, results,
## a room-select grid with its own layout) leave this off.
var show_codex_button := false

var _time := 0.0
var _codex_icon: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_codex_icon = PixelArt.tex("icon_book")


func _process(delta: float) -> void:
	_time += delta
	_handle_input()
	queue_redraw()


func _handle_input() -> void:
	if show_codex_button and Input.is_action_just_pressed("p_codex"):
		Audio.play("menu_select")
		chosen.emit("codex")
		return

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


func set_item_label(id: String, label: String) -> void:
	for item in items:
		if item["id"] == id:
			item["label"] = label
			return


# ------------------------------------------------------------------ draw ---

func _draw() -> void:
	if opaque:
		draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Palette.BG)
		draw_backdrop()
	else:
		var dim := Palette.BG
		dim.a = 0.88
		draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), dim)
	draw_header()

	if not title.is_empty():
		PixelFont.draw_text_centered_shadow(self, title, SCREEN.x * 0.5, 34.0,
			Palette.WHITE, Palette.MAGENTA_DARK, 3)
	if not subtitle.is_empty():
		PixelFont.draw_text_centered(self, subtitle, SCREEN.x * 0.5, 62.0, Palette.GREY, 1)

	# Over a live room the list needs its own ground to sit on, or the terrain
	# behind it competes with the text.
	if not opaque and not items.is_empty():
		Util.draw_panel(self, Rect2(_list_left() - 6.0, list_top - 8.0,
			list_width + 12.0, items.size() * line_height + 10.0),
			Palette.BG, Palette.FRAME)

	for i in items.size():
		_draw_item(i)

	if not footer.is_empty():
		PixelFont.draw_text_centered(self, footer, SCREEN.x * 0.5, SCREEN.y - 16.0,
			Palette.GREY_DARK, 1)

	if show_codex_button:
		_draw_codex_button()


func _list_left() -> float:
	return roundf((SCREEN.x - list_width) * 0.5)


## Label and value as one centred line, cursor riding beside it. This is the
## line_height fix from before (20px, not 14 — glyphs are 14px tall at this
## scale, so 14 left the rows touching) with the centred layout kept.
func _draw_item(i: int) -> void:
	var item: Dictionary = items[i]
	var y := list_top + i * line_height
	var selected := i == cursor

	var label := str(item["label"])
	var value := str(item.get("value", ""))
	if not value.is_empty():
		label += "  " + value

	var color := Palette.WHITE if selected else Palette.GREY_DARK
	PixelFont.draw_text_centered(self, label, SCREEN.x * 0.5, y, color, ITEM_SCALE)

	if selected:
		var size := PixelFont.measure(label, ITEM_SCALE)
		# The marker breathes so the eye finds it instantly.
		var nudge := 0.0 if fmod(_time, 0.7) < 0.35 else 1.0
		var x := SCREEN.x * 0.5 - size.x * 0.5 - CURSOR_GAP - nudge
		PixelFont.draw_text(self, ">", Vector2(roundf(x), y), Palette.MAGENTA, ITEM_SCALE)


## Book icon, top-right, with the shortcut key under it and a pulsing dot
## while something in the codex is still unfound.
func _draw_codex_button() -> void:
	var size := Vector2(_codex_icon.get_width(), _codex_icon.get_height()) * 2.0
	var pos := Vector2(SCREEN.x - size.x - 10.0, 7.0)
	var hover := roundf(sin(_time * 2.2))
	draw_texture_rect(_codex_icon, Rect2(pos + Vector2(0.0, hover), size), false)

	# Unread marker, so the book advertises itself while anything is still
	# undiscovered and then stops nagging once the collection is complete.
	if Save.known_count() < Codex.count() and fmod(_time, 1.0) < 0.6:
		draw_rect(Rect2(pos.x + size.x - 3.0, pos.y - 2.0, 4.0, 4.0), Palette.MAGENTA)

	# A framed keycap rather than a bare letter: this font's "C" on its own
	# reads as a bracket at scale 1.
	# FRAME is only a shade off the background, so the cap gets a grey border to
	# actually be visible as a key.
	var cap := Rect2(pos.x + size.x * 0.5 - 5.0, pos.y + size.y + 3.0, 10.0, 10.0)
	Util.draw_panel(self, cap, Palette.BG_SOFT, Palette.GREY_DARK)
	PixelFont.draw_text_centered(self, "C", cap.position.x + cap.size.x * 0.5,
		cap.position.y + 2.0, Palette.WHITE, 1)


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
