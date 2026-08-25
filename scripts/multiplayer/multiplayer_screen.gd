class_name MultiplayerScreen
extends Menu

## Entry point kept separate from JOGAR: offline never opens a socket.


func _ready() -> void:
	super()
	title = "MULTIPLAYER"
	subtitle = "JOGUE EM MAQUINAS DIFERENTES"
	footer = "ESC VOLTA"
	allow_cancel = true
	list_top = 128.0
	items = [
		{"id": "host", "label": "CRIAR SALA LAN"},
		{"id": "join", "label": "ENTRAR POR IP"},
		{"id": "back", "label": "VOLTAR"},
	]
