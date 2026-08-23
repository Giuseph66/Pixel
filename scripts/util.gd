class_name Util
extends RefCounted


## Seconds as M:SS.CC — the format a speedrun timer wants.
static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--"
	var total := floori(seconds)
	var minutes := total / 60
	var secs := total % 60
	var cents := roundi((seconds - float(total)) * 100.0)
	if cents >= 100:
		cents = 99
	return "%d:%02d.%02d" % [minutes, secs, cents]


## Panel with a one pixel border, used by every screen.
static func draw_panel(ci: CanvasItem, rect: Rect2, fill: Color, border: Color) -> void:
	ci.draw_rect(rect, fill)
	ci.draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 1), border)
	ci.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - 1, rect.size.x, 1), border)
	ci.draw_rect(Rect2(rect.position.x, rect.position.y, 1, rect.size.y), border)
	ci.draw_rect(Rect2(rect.position.x + rect.size.x - 1, rect.position.y, 1, rect.size.y), border)
