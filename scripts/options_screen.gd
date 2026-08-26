class_name OptionsScreen
extends Menu

## Audio and language, moved off the title screen so the front page can go back
## to being four things you might actually want to press.
##
## Every entry here toggles in place rather than opening anything, so the screen
## rebuilds its own labels instead of asking Main to do it.

const VOLUME_STEP := 10


func _ready() -> void:
	super()
	allow_cancel = true
	list_top = 104.0
	items = [
		{"id": "music", "label": "", "value": ""},
		{"id": "sfx", "label": "", "value": ""},
		{"id": "language", "label": "", "value": ""},
		{"id": "back", "label": "", "value": ""},
	]
	refresh_labels()


func _volume_percent(kind: String) -> int:
	if not bool(Save.settings.get(kind, true)):
		return 0
	return clampi(int(Save.settings.get("%s_volume" % kind, 100)), 0, 100)


func refresh_labels() -> void:
	title = Lang.t("options.title")
	footer = Lang.t("options.footer")
	set_item_label("music", Lang.t("title.music"))
	set_item_label("sfx", Lang.t("title.sfx"))
	set_item_label("language", Lang.t("title.language"))
	set_item_label("back", Lang.t("options.back"))

	set_item_value("music", "%d%%" % _volume_percent("music"))
	set_item_value("sfx", "%d%%" % _volume_percent("sfx"))
	set_item_value("language", Lang.language_name())
	queue_redraw()


func _handle_input() -> void:
	var id := str(items[cursor]["id"]) if not items.is_empty() else ""
	if id == "music" or id == "sfx":
		if Input.is_action_just_pressed("p_left"):
			_change_volume(id, -VOLUME_STEP)
			return
		if Input.is_action_just_pressed("p_right"):
			_change_volume(id, VOLUME_STEP)
			return
	super()


func _change_volume(kind: String, delta: int) -> void:
	var value := clampi(_volume_percent(kind) + delta, 0, 100)
	if kind == "music":
		Save.set_music_volume(value)
		Audio.set_music_volume(float(value) / 100.0)
	else:
		Save.set_sfx_volume(value)
		Audio.set_sfx_volume(float(value) / 100.0)
		Audio.play("menu_move")
	refresh_labels()


## Apply the entry under the cursor. Returns true when the screen handled it,
## false when Main should take over — which only "back" ever does.
func apply(id: String) -> bool:
	match id:
		"music":
			_change_volume("music", VOLUME_STEP)
		"sfx":
			_change_volume("sfx", VOLUME_STEP)
		"language":
			Lang.cycle()
		_:
			return false
	refresh_labels()
	return true
