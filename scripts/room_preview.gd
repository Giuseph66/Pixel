class_name RoomPreview
extends RefCounted

## A room drawn small: one coloured pixel block per tile.
##
## Used by the sandbox list and the import panel, where the point is to
## recognise a room at a glance rather than to read it. Colours come from the
## palette groups, so a preview and the editor agree about what is dangerous.

## Overrides where the group colour is not enough to tell two tiles apart.
const COLORS := {
	".": Palette.BG,
	"#": Palette.GREY_DARK,
	"~": Palette.CYAN,
	"-": Palette.CYAN_MID,
	"c": Palette.GOLD_DARK,
	"k": Palette.GOLD_DARK,
	"P": Palette.WHITE,
	"X": Palette.PURPLE,
	"A": Palette.MAGENTA_DARK,
}


static func color_of(ch: String) -> Color:
	if COLORS.has(ch):
		return COLORS[ch]
	if not TilePalette.exists(ch):
		return Palette.BG
	return TilePalette.group_color(TilePalette.group_of(ch))


## Draw `rows` filling `rect`, at whole-pixel block size so the preview stays
## on the pixel grid. Air is left as the panel's own background.
static func draw(ci: CanvasItem, rows: PackedStringArray, rect: Rect2) -> void:
	if rows.is_empty():
		return
	var block := maxf(1.0, floorf(minf(rect.size.x / Levels.COLS, rect.size.y / Levels.ROWS)))
	var origin := Vector2(
		roundf(rect.position.x + (rect.size.x - block * Levels.COLS) * 0.5),
		roundf(rect.position.y + (rect.size.y - block * Levels.ROWS) * 0.5)
	)

	for ty in mini(rows.size(), Levels.ROWS):
		var row := rows[ty]
		var tx := 0
		while tx < mini(row.length(), Levels.COLS):
			var ch := row[tx]
			if ch == ".":
				tx += 1
				continue
			# Merge each horizontal run into one draw_rect: a full floor is one
			# call instead of sixty, and a screen of cards has a few hundred
			# rectangles rather than tens of thousands.
			var run := 1
			while tx + run < mini(row.length(), Levels.COLS) and row[tx + run] == ch:
				run += 1
			ci.draw_rect(Rect2(origin + Vector2(tx * block, ty * block),
				Vector2(block * run, block)), color_of(ch))
			tx += run
