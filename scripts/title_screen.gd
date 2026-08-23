class_name TitleScreen
extends Menu

## The logo, rebuilt live: the cube hovers, the wordmark sits under it, and the
## dashed rule underneath is the same one the exported logo has.

var _cube: Texture2D
var _stats := ""


func _ready() -> void:
	super()
	_cube = PixelArt.cube(8)
	title = ""
	list_top = 146.0

	# Four things you might actually want to press. Story vs. endless is a
	# choice inside PLAY now (see play_select_screen.gd) rather than a fifth
	# row here; audio and language live in their own OPTIONS screen.
	items = [
		{"id": "play", "label": ""},
		{"id": "levels", "label": ""},
		{"id": "options", "label": ""},
	]
	if OS.get_name() != "Web":
		items.append({"id": "quit", "label": ""})

	refresh_labels()


## Rebuild every piece of text on the screen. Called on load and again whenever
## the language changes.
func refresh_labels() -> void:
	footer = Lang.t("title.footer")
	for item: Dictionary in items:
		item["label"] = Lang.t("title." + str(item["id"]))

	var cleared := Save.cleared_count()
	_stats = ""
	if cleared > 0:
		_stats = Lang.tf("title.stats", [cleared, Levels.count(), Save.total_gems()])
	queue_redraw()


func draw_header() -> void:
	var cx := SCREEN.x * 0.5
	var hover := roundf(sin(_time * 1.8) * 2.0)

	draw_texture(_cube, Vector2(roundf(cx - _cube.get_width() * 0.5), 30.0 + hover))

	var word := "PIXEL"
	var scale := 5
	var size := PixelFont.measure(word, scale)
	var pos := Vector2(roundf(cx - size.x * 0.5), 78.0)
	PixelFont.draw_text(self, word, pos + Vector2(scale, scale), Palette.MAGENTA_DARK, scale)
	PixelFont.draw_text(self, word, pos, Palette.WHITE, scale)

	var rule_y := pos.y + size.y + 5.0
	var x := pos.x
	while x < pos.x + size.x - scale:
		draw_rect(Rect2(x, rule_y, scale, 2), Palette.MAGENTA)
		x += scale * 2

	if not _stats.is_empty():
		PixelFont.draw_text_centered(self, _stats, cx, rule_y + 12.0, Palette.GREY_DARK, 1)
