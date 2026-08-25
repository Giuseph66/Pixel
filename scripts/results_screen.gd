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
## Bitmask of everything this room has ever earned, and the subset this attempt
## earned for the first time — the new ones are the only ones worth a flash.
var medals := 0
var new_medals := 0

## Endless mode reuses the second row for the run's running total, so it gets
## to rename it. Left empty, it reads "BEST".
var best_label := ""

var _reveal := 0.0


func _ready() -> void:
	super()
	title = Lang.t("results.title")
	subtitle = Lang.t(level_name)
	if best_label.is_empty():
		best_label = Lang.t("results.best")
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
	_row(panel, 1, best_label, Util.format_time(best),
		Palette.GOLD if new_record else Palette.GREY)
	_row(panel, 2, Lang.t("results.gems"), "%d / %d" % [gems, gems_total],
		Palette.GOLD if gems_total > 0 and gems >= gems_total else Palette.GREY)
	_row(panel, 3, Lang.t("results.deaths"), str(deaths), Palette.GREY)

	_draw_medals(panel)

	# Both of these sit in the empty middle of the last row, between the
	# "DEATHS" label and its value, which is the only gap left inside the panel.
	var note_y := panel.position.y + panel.size.y - 13.0
	if new_record and fmod(_time, 0.9) < 0.55:
		PixelFont.draw_text_centered(self, Lang.t("results.record"), cx, note_y,
			Palette.MAGENTA, 1)
	elif under_par:
		PixelFont.draw_text_centered(self, Lang.tf("results.under_par",
			[Util.format_time(par)]), cx, note_y, Palette.GREY_DARK, 1)


## Three seals along the foot of the panel: under par, every gem, no deaths.
## They are independent on purpose — the fast route and the greedy route are
## rarely the same one, so a room worth mastering takes more than one visit.
##
## Icons only, in the eighteen-pixel band between the panel and the menu.
## Naming each seal here would need three labels across 260 pixels and they ran
## straight through the menu underneath; the level select and the codex carry
## the words instead.
const MEDALS := [
	{"bit": 1, "sprite": "medal_time", "colour": Palette.CYAN},
	{"bit": 2, "sprite": "medal_gems", "colour": Palette.GOLD},
	{"bit": 4, "sprite": "medal_clean", "colour": Palette.WHITE},
]
const MEDAL_STEP := 13.0


func _draw_medals(panel: Rect2) -> void:
	if gems_total <= 0 and par <= 0.0:
		return

	var y := panel.position.y + panel.size.y + 9.0
	var x := panel.position.x + panel.size.x * 0.5 - MEDAL_STEP
	for entry: Dictionary in MEDALS:
		var bit := int(entry["bit"])
		var held := (medals & bit) != 0
		var colour: Color = entry["colour"] if held else Palette.FRAME
		# One won just now blinks; one carried in from an earlier visit sits still.
		if (new_medals & bit) != 0 and fmod(_time, 0.5) < 0.25:
			colour = Palette.MAGENTA

		var icon := PixelArt.tex(String(entry["sprite"]))
		draw_texture(icon, Vector2(x - icon.get_width() * 0.5,
			y - icon.get_height() * 0.5), colour)
		x += MEDAL_STEP


func _row(panel: Rect2, i: int, label: String, value: String, color: Color) -> void:
	var y := panel.position.y + 12.0 + i * 17.0
	PixelFont.draw_text(self, label, Vector2(panel.position.x + 14.0, y), Palette.GREY_DARK, 1)
	var size := PixelFont.measure(value, 2)
	PixelFont.draw_text(self, value,
		Vector2(panel.position.x + panel.size.x - 14.0 - size.x, y - 4.0), color, 2)
