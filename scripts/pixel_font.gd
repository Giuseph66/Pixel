class_name PixelFont
extends RefCounted

## The game's only typeface: a hand-drawn 5x7 bitmap font.
##
## It is not a Font resource — glyphs are painted with draw_rect() straight onto
## any CanvasItem, so the text stays exactly as crisp as the rest of the art and
## needs no import step. The same grids are used by the logo generator in
## logo/make_logo.py.

const W := 5
const H := 7
const TRACKING := 1

const GLYPHS := {
	"A": "01110/10001/10001/11111/10001/10001/10001",
	"B": "11110/10001/10001/11110/10001/10001/11110",
	"C": "01111/10000/10000/10000/10000/10000/01111",
	"D": "11110/10001/10001/10001/10001/10001/11110",
	"E": "11111/10000/10000/11110/10000/10000/11111",
	"F": "11111/10000/10000/11110/10000/10000/10000",
	"G": "01111/10000/10000/10111/10001/10001/01111",
	"H": "10001/10001/10001/11111/10001/10001/10001",
	"I": "11111/00100/00100/00100/00100/00100/11111",
	"J": "00111/00010/00010/00010/00010/10010/01100",
	"K": "10001/10010/10100/11000/10100/10010/10001",
	"L": "10000/10000/10000/10000/10000/10000/11111",
	"M": "10001/11011/10101/10101/10001/10001/10001",
	"N": "10001/11001/10101/10101/10011/10001/10001",
	"O": "01110/10001/10001/10001/10001/10001/01110",
	"P": "11110/10001/10001/11110/10000/10000/10000",
	"Q": "01110/10001/10001/10001/10101/10010/01101",
	"R": "11110/10001/10001/11110/10100/10010/10001",
	"S": "01111/10000/10000/01110/00001/00001/11110",
	"T": "11111/00100/00100/00100/00100/00100/00100",
	"U": "10001/10001/10001/10001/10001/10001/01110",
	"V": "10001/10001/10001/10001/10001/01010/00100",
	"W": "10001/10001/10001/10101/10101/11011/10001",
	"X": "10001/10001/01010/00100/01010/10001/10001",
	"Y": "10001/10001/01010/00100/00100/00100/00100",
	"Z": "11111/00001/00010/00100/01000/10000/11111",
	"0": "01110/10011/10011/10101/11001/11001/01110",
	"1": "00100/01100/00100/00100/00100/00100/01110",
	"2": "01110/10001/00001/00110/01000/10000/11111",
	"3": "11110/00001/00001/01110/00001/00001/11110",
	"4": "00010/00110/01010/10010/11111/00010/00010",
	"5": "11111/10000/11110/00001/00001/10001/01110",
	"6": "00110/01000/10000/11110/10001/10001/01110",
	"7": "11111/00001/00010/00100/01000/01000/01000",
	"8": "01110/10001/10001/01110/10001/10001/01110",
	"9": "01110/10001/10001/01111/00001/00010/01100",
	" ": "00000/00000/00000/00000/00000/00000/00000",
	".": "00000/00000/00000/00000/00000/01100/01100",
	",": "00000/00000/00000/00000/01100/01100/01000",
	":": "00000/01100/01100/00000/01100/01100/00000",
	";": "00000/01100/01100/00000/01100/01100/01000",
	"'": "01100/01100/01000/00000/00000/00000/00000",
	"!": "00100/00100/00100/00100/00100/00000/00100",
	"?": "01110/10001/00001/00110/00100/00000/00100",
	"-": "00000/00000/00000/11111/00000/00000/00000",
	"+": "00000/00100/00100/11111/00100/00100/00000",
	"=": "00000/00000/11111/00000/11111/00000/00000",
	"/": "00001/00001/00010/00100/01000/10000/10000",
	"*": "00000/10101/01110/11111/01110/10101/00000",
	"%": "11001/11010/00010/00100/01000/01011/10011",
	"(": "00010/00100/01000/01000/01000/00100/00010",
	")": "01000/00100/00010/00010/00010/00100/01000",
	"[": "01110/01000/01000/01000/01000/01000/01110",
	"]": "01110/00010/00010/00010/00010/00010/01110",
	"<": "00010/00100/01000/10000/01000/00100/00010",
	">": "01000/00100/00010/00001/00010/00100/01000",
	"_": "00000/00000/00000/00000/00000/00000/11111",
	"#": "01010/01010/11111/01010/11111/01010/01010",
	"@": "01110/10001/10111/10101/10111/10000/01110",
	"^": "00100/01110/11011/00000/00000/00000/00000",

	# Accented capitals. The mark takes the top two rows and the letter is
	# redrawn five rows tall underneath, so the glyph box stays 5x7 and every
	# layout in the game keeps its metrics.
	"Á": "00010/00100/01110/10001/11111/10001/10001",
	"À": "01000/00100/01110/10001/11111/10001/10001",
	"Â": "00100/01010/01110/10001/11111/10001/10001",
	"Ã": "01101/10110/01110/10001/11111/10001/10001",
	"Ä": "01010/00000/01110/10001/11111/10001/10001",
	"É": "00010/00100/11111/10000/11110/10000/11111",
	"È": "01000/00100/11111/10000/11110/10000/11111",
	"Ê": "00100/01010/11111/10000/11110/10000/11111",
	"Ë": "01010/00000/11111/10000/11110/10000/11111",
	"Í": "00010/00100/11111/00100/00100/00100/11111",
	"Ì": "01000/00100/11111/00100/00100/00100/11111",
	"Î": "00100/01010/11111/00100/00100/00100/11111",
	"Ï": "01010/00000/11111/00100/00100/00100/11111",
	"Ó": "00010/00100/01110/10001/10001/10001/01110",
	"Ò": "01000/00100/01110/10001/10001/10001/01110",
	"Ô": "00100/01010/01110/10001/10001/10001/01110",
	"Õ": "01101/10110/01110/10001/10001/10001/01110",
	"Ö": "01010/00000/01110/10001/10001/10001/01110",
	"Ú": "00010/00100/10001/10001/10001/10001/01110",
	"Ù": "01000/00100/10001/10001/10001/10001/01110",
	"Û": "00100/01010/10001/10001/10001/10001/01110",
	"Ü": "01010/00000/10001/10001/10001/10001/01110",
	"Ñ": "01101/10110/10001/11001/10101/10011/10001",
	"Ç": "01111/10000/10000/10000/10000/01111/00110",
	"¡": "00100/00000/00100/00100/00100/00100/00100",
	"¿": "00100/00000/00100/01000/10000/10001/01110",
}

const FALLBACK := "?"


## Pixel size of `text` when rendered at `scale`.
static func measure(text: String, scale: int = 1) -> Vector2:
	if text.is_empty():
		return Vector2(0, H * scale)
	var cells := text.length() * W + (text.length() - 1) * TRACKING
	return Vector2(cells * scale, H * scale)


## Advance in pixels from one glyph origin to the next.
static func advance(scale: int = 1) -> int:
	return (W + TRACKING) * scale


## Paint `text` onto `ci` with its top-left corner at `pos`.
## Runs of lit pixels on the same row are merged into a single draw_rect call.
## Break `text` into lines that each fit inside `width`.
##
## Splits after spaces and after slashes. The slash matters more than it looks:
## the longest strings this game ever puts on screen are file paths, and a path
## has no spaces in it to break at, so without that rule a path is one line that
## runs off both edges of its panel.
static func wrap(text: String, width: float, scale: int = 1) -> PackedStringArray:
	var out := PackedStringArray()
	var per := float(advance(scale))
	var fits := maxi(floori(width / per), 1)
	if text.length() <= fits:
		out.append(text)
		return out

	var line := ""
	var mark := -1                  # last index in `line` a break is allowed at
	for i in text.length():
		var ch := text[i]
		line += ch
		if ch == " " or ch == "/":
			mark = line.length()
		if line.length() < fits:
			continue
		# Full. Cut at the last break point, or mid-word if there was none.
		var cut := mark if mark > 0 else line.length()
		out.append(line.substr(0, cut))
		line = line.substr(cut)
		mark = -1
	if not line.is_empty():
		out.append(line)
	return out


static func draw_text(ci: CanvasItem, text: String, pos: Vector2, color: Color, scale: int = 1) -> void:
	var upper := text.to_upper()
	var origin_x := pos.x
	for i in upper.length():
		var ch := upper[i]
		if not GLYPHS.has(ch):
			ch = FALLBACK
		var rows: PackedStringArray = GLYPHS[ch].split("/")
		var gx := origin_x + i * advance(scale)
		for row_index in rows.size():
			var row := rows[row_index]
			var x := 0
			while x < W:
				if row[x] == "1":
					var run := 1
					while x + run < W and row[x + run] == "1":
						run += 1
					ci.draw_rect(Rect2(
						gx + x * scale,
						pos.y + row_index * scale,
						run * scale,
						scale
					), color)
					x += run
				else:
					x += 1


## draw_text() with a hard offset drop shadow underneath, the same trick the
## wordmark in the logo uses.
static func draw_text_shadow(ci: CanvasItem, text: String, pos: Vector2, color: Color,
		shadow: Color, scale: int = 1, offset: Vector2 = Vector2.ONE) -> void:
	draw_text(ci, text, pos + offset * scale, shadow, scale)
	draw_text(ci, text, pos, color, scale)


## Paint `text` horizontally centred on `center_x`.
static func draw_text_centered(ci: CanvasItem, text: String, center_x: float, y: float,
		color: Color, scale: int = 1) -> void:
	var size := measure(text, scale)
	draw_text(ci, text, Vector2(roundf(center_x - size.x * 0.5), y), color, scale)


static func draw_text_centered_shadow(ci: CanvasItem, text: String, center_x: float, y: float,
		color: Color, shadow: Color, scale: int = 1) -> void:
	var size := measure(text, scale)
	var pos := Vector2(roundf(center_x - size.x * 0.5), y)
	draw_text_shadow(ci, text, pos, color, shadow, scale)
