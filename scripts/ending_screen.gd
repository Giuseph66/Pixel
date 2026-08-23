class_name EndingScreen
extends Menu

## The summary panel, used twice: after the last story room, and when an
## endless run ends. Both are totals — the game is short enough that the
## interesting number is how the whole thing added up.

var total_time := 0.0
var total_gems := 0
var max_gems := 0
var deaths := 0

## Endless mode fills these in instead of the story totals.
var endless := false
var rooms := 0
var new_record := false

var _rows: Array = []           # [{ "label": String, "value": String, "color": Color }]
var _cube: Texture2D


func _ready() -> void:
	super()
	_cube = PixelArt.cube(8)
	list_top = 206.0
	footer = ""

	if endless:
		title = Lang.t("endless.title")
		subtitle = Lang.t("endless.subtitle")
		_rows = [
			_make("endless.depth", str(rooms), Palette.GOLD),
			_make("endless.time", Util.format_time(total_time), Palette.GREY),
			_make("endless.gems", str(total_gems), Palette.GREY),
			_make("endless.deaths", str(deaths), Palette.GREY),
		]
		items = [
			{"id": "endless", "label": Lang.t("title.endless")},
			{"id": "title", "label": Lang.t("ending.menu")},
		]
	else:
		title = Lang.t("ending.title")
		subtitle = Lang.t("ending.subtitle")
		_rows = [
			_make("ending.total_time", Util.format_time(total_time), Palette.GOLD),
			_make("ending.gems", "%d / %d" % [total_gems, max_gems],
				Palette.GOLD if total_gems >= max_gems and max_gems > 0 else Palette.GREY),
			_make("ending.deaths", str(deaths), Palette.GREY),
		]
		items = [
			{"id": "levels", "label": Lang.t("ending.rooms")},
			{"id": "title", "label": Lang.t("ending.menu")},
		]


func _make(key: String, value: String, color: Color) -> Dictionary:
	return {"label": Lang.t(key), "value": value, "color": color}


func draw_header() -> void:
	var cx := SCREEN.x * 0.5
	var hover := roundf(sin(_time * 1.6) * 2.0)
	draw_texture(_cube, Vector2(roundf(cx - _cube.get_width() * 0.5), 76.0 + hover))

	# The panel grows downwards from a fixed bottom edge, so three rows and
	# four rows both sit the same distance above the menu.
	var spacing := 20.0 if _rows.size() <= 3 else 18.0
	var height := 14.0 + _rows.size() * spacing
	var panel := Rect2(cx - 120.0, 192.0 - height, 240.0, height)
	Util.draw_panel(self, panel, Palette.BG_SOFT, Palette.FRAME)

	for i in _rows.size():
		var row: Dictionary = _rows[i]
		_row(panel, i, spacing, row["label"], row["value"], row["color"])

	if new_record and fmod(_time, 0.9) < 0.55:
		PixelFont.draw_text_centered(self, Lang.t("endless.record"), cx,
			panel.position.y - 12.0, Palette.MAGENTA, 1)


func _row(panel: Rect2, i: int, spacing: float, label: String, value: String,
		color: Color) -> void:
	var y := panel.position.y + 12.0 + i * spacing
	PixelFont.draw_text(self, label, Vector2(panel.position.x + 14.0, y), Palette.GREY_DARK, 1)
	var size := PixelFont.measure(value, 2)
	PixelFont.draw_text(self, value,
		Vector2(panel.position.x + panel.size.x - 14.0 - size.x, y - 4.0), color, 2)
