class_name ResultsScreen
extends Menu

## Shown the moment a room is finished. The numbers count up rather than
## appearing, which is the cheapest way to make a summary feel earned.

var level_name := ""
var time := 0.0
var best := 0.0
var new_record := false
var gems := 0
var gems_total := 0
var deaths := 0
var par := 0.0

var _reveal := 0.0


func _ready() -> void:
	super()
	title = Lang.t("results.title")
	subtitle = Lang.t(level_name)
	list_top = 186.0
	footer = Lang.t("results.footer")


func _process(delta: float) -> void:
	_reveal = minf(_reveal + delta * 1.6, 1.0)
	super(delta)


func draw_header() -> void:
	var cx := SCREEN.x * 0.5
	var panel := Rect2(cx - 130.0, 84.0, 260.0, 84.0)
	Util.draw_panel(self, panel, Palette.BG_SOFT, Palette.FRAME)

	var shown_time := time * minf(_reveal * 1.4, 1.0)
	var under_par := time <= par and par > 0.0

	_row(panel, 0, Lang.t("results.time"), Util.format_time(shown_time),
		Palette.GOLD if under_par else Palette.WHITE)
	_row(panel, 1, Lang.t("results.best"), Util.format_time(best),
		Palette.GOLD if new_record else Palette.GREY)
	_row(panel, 2, Lang.t("results.gems"), "%d / %d" % [gems, gems_total],
		Palette.GOLD if gems_total > 0 and gems >= gems_total else Palette.GREY)
	_row(panel, 3, Lang.t("results.deaths"), str(deaths), Palette.GREY)

	if new_record and fmod(_time, 0.9) < 0.55:
		PixelFont.draw_text_centered(self, Lang.t("results.record"), cx,
			panel.position.y + 90.0, Palette.MAGENTA, 1)
	elif under_par:
		PixelFont.draw_text_centered(self, Lang.tf("results.under_par",
			[Util.format_time(par)]), cx, panel.position.y + 90.0, Palette.GREY_DARK, 1)


func _row(panel: Rect2, i: int, label: String, value: String, color: Color) -> void:
	var y := panel.position.y + 12.0 + i * 17.0
	PixelFont.draw_text(self, label, Vector2(panel.position.x + 14.0, y), Palette.GREY_DARK, 1)
	var size := PixelFont.measure(value, 2)
	PixelFont.draw_text(self, value,
		Vector2(panel.position.x + panel.size.x - 14.0 - size.x, y - 4.0), color, 2)
