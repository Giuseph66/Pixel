class_name PauseMenu
extends Menu


func _ready() -> void:
	super()
	opaque = false
	allow_cancel = true
	title = Lang.t("pause.title")
	list_top = 116.0
	footer = Lang.t("pause.footer")
	items = [
		{"id": "resume", "label": Lang.t("pause.resume")},
		{"id": "restart", "label": Lang.t("pause.restart")},
		{"id": "levels", "label": Lang.t("pause.rooms")},
		{"id": "title", "label": Lang.t("pause.menu")},
	]
