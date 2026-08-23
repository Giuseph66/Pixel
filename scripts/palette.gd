class_name Palette
extends RefCounted

## The whole game draws from these sixteen colours and nothing else.
## Keeping the list this short is what makes the art read as one piece.

const BG := Color("0f0f1b")
const BG_SOFT := Color("16162a")
const FRAME := Color("2a2a44")
const OUTLINE := Color("07070f")

const WHITE := Color("f2f4ff")
const GREY := Color("b9c0d8")
const GREY_DARK := Color("6b7391")

const CYAN := Color("7ce8ff")
const CYAN_MID := Color("3aa7d8")
const CYAN_DARK := Color("1c5c8c")

const MAGENTA := Color("ff4d6d")
const MAGENTA_DARK := Color("a82545")

const GOLD := Color("ffcc4d")
const GOLD_DARK := Color("d18b21")

const GREEN := Color("7ee787")
const GREEN_DARK := Color("3f9e58")

const PURPLE := Color("9b6bff")

## Single-character keys used by every sprite grid in pixel_art.gd.
const CHARS := {
	".": Color(0, 0, 0, 0),
	"#": OUTLINE,
	"w": WHITE,
	"1": GREY,
	"2": GREY_DARK,
	"c": CYAN,
	"C": CYAN_MID,
	"D": CYAN_DARK,
	"m": MAGENTA,
	"M": MAGENTA_DARK,
	"y": GOLD,
	"Y": GOLD_DARK,
	"g": GREEN,
	"G": GREEN_DARK,
	"p": PURPLE,
	"f": FRAME,
	"b": BG_SOFT,
	"k": BG,
}
