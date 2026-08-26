class_name ModifierScreen
extends Menu

## Step 20 — endless modifiers. Reuses Menu's list skeleton wholesale: picking
## a modifier combo is exactly the same shape as picking a level or an option
## — a cursor over rows, accept to choose.
##
## Three combinations are rolled fresh every visit, plus a "no twist" row that
## always sits first — the campaign is where a rule is fixed and the player
## learns it; the infinite is where it varies, but never by force. Choosing
## classic play is always on the table.

const ALL_MODS := ["rush", "heavy", "brittle", "dark"]
## Every valid pairing, precomputed once: no rush+heavy (both change movement,
## and the combination is unreadable), never more than two at a time.
const VALID_COMBOS := [
	["rush"], ["heavy"], ["brittle"], ["dark"],
	["rush", "brittle"], ["rush", "dark"],
	["heavy", "brittle"], ["heavy", "dark"],
	["brittle", "dark"],
]

const MULTIPLIER := {
	"rush": 1.15,
	"heavy": 1.2,
	"brittle": 1.25,
	"dark": 1.4,
}


func _ready() -> void:
	title = Lang.t("mod.title")
	allow_cancel = true

	items = [{"id": "", "label": Lang.t("mod.none.name"), "value": ""}]
	var pool := VALID_COMBOS.duplicate()
	pool.shuffle()
	for combo: Array in pool.slice(0, 3):
		items.append({"id": combo_key(combo), "label": _combo_label(combo), "value": ""})

	super()


static func combo_key(combo: Array) -> String:
	var mods: Array = combo.duplicate()
	mods.sort()
	return "+".join(mods)


static func mods_from_key(key: String) -> Array[String]:
	var out: Array[String] = []
	if key.is_empty():
		return out
	for m in key.split("+"):
		out.append(m)
	return out


## The product of every active mod's multiplier — a run with two hard twists
## is worth more than either alone, not just whichever is worst.
static func score_multiplier(mods: Array) -> float:
	var m := 1.0
	for id in mods:
		m *= float(MULTIPLIER.get(id, 1.0))
	return m


func _combo_label(combo: Array) -> String:
	var parts: Array[String] = []
	for id: String in combo:
		parts.append(Lang.t("mod.%s.name" % id))
	return " + ".join(parts)


func draw_header() -> void:
	# The chosen row's own text is the description — Menu draws the list
	# under the title, so the explanation goes where the cursor already is.
	if items.is_empty():
		return
	var id := str(items[cursor]["id"])
	var text := Lang.t("mod.none.text") if id.is_empty() else _combo_text(mods_from_key(id))
	PixelFont.draw_text_centered(self, text, SCREEN.x * 0.5, 100.0, Palette.GREY, 1)


func _combo_text(mods: Array) -> String:
	var parts: Array[String] = []
	for id: String in mods:
		parts.append(Lang.t("mod.%s.text" % id))
	return "  ".join(parts)
