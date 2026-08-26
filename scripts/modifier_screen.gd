class_name ModifierScreen
extends Node2D

## Step 20 — endless modifiers, picked rather than dealt.
##
## All nine valid combos sit on screen at once, three by three, in the same
## fixed order every visit — no shuffle, no "three of nine, reroll by
## leaving". CLASSIC sits in its own row above the grid: the campaign is
## where a rule is fixed and the player learns it, the infinite is where it
## varies, but only ever by choice, never by draw. Up from the grid's top row
## reaches it; down from CLASSIC lands back on whichever column was open last.

signal chosen(id: String)
signal cancelled

const SCREEN := Vector2(480, 270)

const ALL_MODS := ["rush", "heavy", "brittle", "dark"]
## Every valid pairing: no rush+heavy (both change movement, and the
## combination is unreadable), never more than two at a time. Row-major
## reading order for the grid below — singles first, then every pair.
const VALID_COMBOS := [
	["rush"], ["heavy"], ["brittle"],
	["dark"], ["rush", "brittle"], ["rush", "dark"],
	["heavy", "brittle"], ["heavy", "dark"], ["brittle", "dark"],
]

const MULTIPLIER := {
	"rush": 1.15,
	"heavy": 1.2,
	"brittle": 1.25,
	"dark": 1.4,
}

## Every mod gets a fixed hue rather than sharing the grid's one grey — the
## dot beside a name and the card's own idle border both read off this, so a
## card says what it does before its text is even read. MAGENTA is left out:
## it is the cursor's colour everywhere else in the game, and a mod wearing
## it would look selected when it is not.
const MOD_COLOR := {
	"rush": Palette.CYAN,
	"heavy": Palette.GOLD,
	"brittle": Palette.GREEN,
	"dark": Palette.PURPLE,
}

const COLUMNS := 3
const ROWS := 3
const CARD := Vector2(140, 40)
const GAP := Vector2(10, 8)
const GRID_TOP := 106.0
const ORIGIN_X := (SCREEN.x - (CARD.x * COLUMNS + GAP.x * (COLUMNS - 1))) * 0.5
## Same width as the grid beneath it, so the two read as one column of shapes.
const CLASSIC_RECT := Rect2(ORIGIN_X, 76.0, CARD.x * COLUMNS + GAP.x * (COLUMNS - 1), 18.0)

## 0 is CLASSIC; 1..9 is VALID_COMBOS[selected - 1].
var _selected := 0
## The grid column to land on when moving back down out of CLASSIC — without
## this, up-then-down would always dump the cursor on column 0 regardless of
## where it had been, which reads as the grid forgetting itself.
var _col_memory := 0
var _time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_time += delta
	_handle_input()
	queue_redraw()


func _handle_input() -> void:
	if Input.is_action_just_pressed("p_left"):
		_move(-1, 0)
	elif Input.is_action_just_pressed("p_right"):
		_move(1, 0)
	elif Input.is_action_just_pressed("p_up"):
		_move(0, -1)
	elif Input.is_action_just_pressed("p_down"):
		_move(0, 1)
	elif Input.is_action_just_pressed("p_accept"):
		Audio.play("menu_select")
		chosen.emit(_id_for(_selected))
	elif Input.is_action_just_pressed("p_cancel"):
		Audio.play("menu_back")
		cancelled.emit()


func _move(dx: int, dy: int) -> void:
	if _selected == 0:
		if dy > 0:
			_selected = 1 + _col_memory
		elif dy < 0:
			_selected = 1 + (ROWS - 1) * COLUMNS + _col_memory
		else:
			return
		Audio.play("menu_move")
		return

	var i := _selected - 1
	var col := i % COLUMNS
	var row := i / COLUMNS
	if dx != 0:
		col = wrapi(col + dx, 0, COLUMNS)
		_selected = 1 + row * COLUMNS + col
		_col_memory = col
	elif dy != 0:
		row += dy
		if row < 0 or row >= ROWS:
			_selected = 0
		else:
			_selected = 1 + row * COLUMNS + col
			_col_memory = col
	else:
		return
	Audio.play("menu_move")


func _id_for(selected: int) -> String:
	if selected == 0:
		return ""
	return combo_key(VALID_COMBOS[selected - 1])


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


func _combo_text(mods: Array) -> String:
	var parts: Array[String] = []
	for id: String in mods:
		parts.append(Lang.t("mod.%s.text" % id))
	return "  ".join(parts)


func _card_rect(index: int) -> Rect2:
	var col := index % COLUMNS
	var row := index / COLUMNS
	return Rect2(ORIGIN_X + col * (CARD.x + GAP.x), GRID_TOP + row * (CARD.y + GAP.y), CARD.x, CARD.y)


# -------------------------------------------------------------------- draw ---

func _draw() -> void:
	draw_rect(Rect2(0, 0, SCREEN.x, SCREEN.y), Palette.BG)
	PixelFont.draw_text_centered_shadow(self, Lang.t("mod.title"), SCREEN.x * 0.5, 34.0,
		Palette.WHITE, Palette.MAGENTA_DARK, 3)

	var desc := Lang.t("mod.none.text") if _selected == 0 else _combo_text(VALID_COMBOS[_selected - 1])
	PixelFont.draw_text_centered(self, desc, SCREEN.x * 0.5, 62.0, Palette.GREY, 1)

	_draw_classic()
	for i in VALID_COMBOS.size():
		_draw_card(i)

	PixelFont.draw_text_centered(self, Lang.t("mod.footer"), SCREEN.x * 0.5, SCREEN.y - 16.0,
		Palette.GREY_DARK, 1)


func _blink_border(selected: bool, idle: Color) -> Color:
	if not selected:
		return idle
	return Palette.MAGENTA if fmod(_time, 0.8) < 0.4 else Palette.WHITE


## A pair's idle border sits between its two mods' colours — close enough to
## either that picking the card up reads as "these two", not a third thing.
func _combo_color(combo: Array) -> Color:
	if combo.size() == 1:
		return MOD_COLOR[combo[0]]
	return (MOD_COLOR[combo[0]] as Color).lerp(MOD_COLOR[combo[1]], 0.5)


func _draw_classic() -> void:
	var selected := _selected == 0
	var idle: Color = Palette.GREY_DARK
	Util.draw_panel(self, CLASSIC_RECT, Palette.BG_SOFT, _blink_border(selected, idle))
	var cx := CLASSIC_RECT.position.x + CLASSIC_RECT.size.x * 0.5
	var y := CLASSIC_RECT.position.y + 5.0
	var label := Lang.t("mod.none.name")
	var w := PixelFont.measure(label, 1).x
	draw_rect(Rect2(cx - w * 0.5 - 9.0, y + 1.0, 3.0, 3.0), Palette.WHITE if selected else Palette.GREY)
	PixelFont.draw_text_centered(self, label, cx, y, Palette.WHITE if selected else Palette.GREY, 1)


func _draw_card(index: int) -> void:
	var rect := _card_rect(index)
	var selected := _selected == index + 1
	var combo: Array = VALID_COMBOS[index]
	var idle: Color = _combo_color(combo).darkened(0.35)
	Util.draw_panel(self, rect, Palette.BG_SOFT, _blink_border(selected, idle))

	var cx := rect.position.x + rect.size.x * 0.5
	var text_color := Palette.WHITE if selected else Palette.GREY
	if combo.size() == 1:
		var mult := float(MULTIPLIER.get(combo[0], 1.0))
		_dotted_line(cx, rect.position.y + 11.0, Lang.t("mod.%s.name" % combo[0]),
			MOD_COLOR[combo[0]], text_color)
		PixelFont.draw_text_centered(self, "x%.2f" % mult,
			cx, rect.position.y + 25.0, Palette.GOLD if selected else Palette.GOLD_DARK, 1)
	else:
		_dotted_line(cx, rect.position.y + 8.0, Lang.t("mod.%s.name" % combo[0]),
			MOD_COLOR[combo[0]], text_color)
		_dotted_line(cx, rect.position.y + 24.0, Lang.t("mod.%s.name" % combo[1]),
			MOD_COLOR[combo[1]], text_color)


## A name with a small filled square riding beside it in the mod's own
## colour — the one cue that survives even when the card is not selected and
## its text has faded to grey.
func _dotted_line(cx: float, y: float, label: String, dot: Color, text_color: Color) -> void:
	var w := PixelFont.measure(label, 1).x
	draw_rect(Rect2(cx - w * 0.5 - 9.0, y + 1.0, 3.0, 3.0), dot)
	PixelFont.draw_text_centered(self, label, cx, y, text_color, 1)
