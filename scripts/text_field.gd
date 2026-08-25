class_name TextField
extends RefCounted

## One line of typed text, for naming a room.
##
## The game has no Control nodes anywhere — every screen is draw_rect() and the
## bitmap font — so this is a plain state machine fed raw key events rather
## than a LineEdit. It only ever accepts characters the font can draw, which
## means what you type is always exactly what the room will show.

var text := ""
var limit := Sandbox.NAME_LIMIT
var digits_only := false

var _blink := 0.0


func tick(delta: float) -> void:
	_blink = fmod(_blink + delta, 1.0)


## Feed a key event. Returns true when the text changed, so the caller knows to
## redraw without diffing strings.
func handle(event: InputEventKey) -> bool:
	if not event.pressed:
		return false

	if event.keycode == KEY_BACKSPACE:
		if text.is_empty():
			return false
		text = text.substr(0, text.length() - 1)
		return true

	var typed := char(event.unicode).to_upper()
	if typed.is_empty() or event.unicode < 32:
		return false
	if digits_only and not (typed >= "0" and typed <= "9") and typed != ".":
		return false
	if not PixelFont.GLYPHS.has(typed):
		return false
	if text.length() >= limit:
		return false
	text += typed
	return true


## The text plus a caret that blinks, which is the only thing telling the
## player the field is live.
func display() -> String:
	return text + ("_" if _blink < 0.55 else " ")


func value() -> float:
	return text.to_float()
