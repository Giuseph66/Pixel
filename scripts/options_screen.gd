class_name OptionsScreen
extends Menu

## Audio and language, moved off the title screen so the front page can go back
## to being four things you might actually want to press.
##
## Every entry here toggles in place rather than opening anything, so the screen
## rebuilds its own labels instead of asking Main to do it.


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


func _on_off(value: bool) -> String:
	return Lang.t("ui.on") if value else Lang.t("ui.off")


func refresh_labels() -> void:
	title = Lang.t("options.title")
	footer = Lang.t("options.footer")
	set_item_label("music", Lang.t("title.music"))
	set_item_label("sfx", Lang.t("title.sfx"))
	set_item_label("language", Lang.t("title.language"))
	set_item_label("back", Lang.t("options.back"))

	set_item_value("music", _on_off(Save.data["music"]))
	set_item_value("sfx", _on_off(Save.data["sfx"]))
	set_item_value("language", Lang.language_name())
	queue_redraw()


## Apply the entry under the cursor. Returns true when the screen handled it,
## false when Main should take over — which only "back" ever does.
func apply(id: String) -> bool:
	match id:
		"music":
			var on := not bool(Save.data["music"])
			Save.set_music(on)
			Audio.set_music_enabled(on)
		"sfx":
			var on := not bool(Save.data["sfx"])
			Save.set_sfx(on)
			Audio.set_sfx_enabled(on)
		"language":
			Lang.cycle()
		_:
			return false
	refresh_labels()
	return true
