class_name PauseMenu
extends Menu

## Set before the menu enters the tree. An endless run has no room list to go
## back to, so its third choice ends the run instead, and a sandbox room goes
## back to the editor it was launched from.
var endless := false
var sandbox := false
var networked := false
var network_host := false


func _ready() -> void:
	super()
	opaque = false
	allow_cancel = true
	title = Lang.t("pause.title")
	list_top = 112.0
	footer = Lang.t("pause.footer")
	show_codex_button = true
	show_options_button = true
	items = [{"id": "resume", "label": Lang.t("pause.resume")}]
	if networked:
		if network_host:
			items.append({"id": "lobby", "label": Lang.t("pause.lobby")})
		items.append({"id": "leave_server", "label": Lang.t("pause.leave_server")})
		return

	items.append({"id": "restart", "label": Lang.t("pause.restart")})
	if endless:
		items.append({"id": "end_run", "label": Lang.t("pause.end_run")})
	elif sandbox:
		items.append({"id": "edit", "label": Lang.t("pause.edit")})
		items.append({"id": "sandbox", "label": Lang.t("pause.sandbox")})
	else:
		items.append({"id": "levels", "label": Lang.t("pause.rooms")})
	items.append({"id": "title", "label": Lang.t("pause.menu")})
