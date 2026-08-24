class_name PauseMenu
extends Menu

## Set before the menu enters the tree. An endless run has no room list to go
## back to, so its third choice ends the run instead.
var endless := false


func _ready() -> void:
	super()
	opaque = false
	allow_cancel = true
	title = Lang.t("pause.title")
	list_top = 112.0
	footer = Lang.t("pause.footer")
	show_codex_button = true
	items = [
		{"id": "resume", "label": Lang.t("pause.resume")},
		{"id": "restart", "label": Lang.t("pause.restart")},
	]
	if endless:
		items.append({"id": "end_run", "label": Lang.t("pause.end_run")})
	else:
		items.append({"id": "levels", "label": Lang.t("pause.rooms")})
	items.append({"id": "title", "label": Lang.t("pause.menu")})
