class_name MultiplayerScreen
extends Menu

## Entry point kept separate from JOGAR: offline never opens a socket.


func _ready() -> void:
	super()
	title = "MULTIPLAYER"
	subtitle = "ONLINE POR CODIGO OU LAN"
	footer = "ESC VOLTA"
	allow_cancel = true
	list_top = 128.0
	items = [
		{"id": "host", "label": "CRIAR SALA"},
		{"id": "join", "label": "ENTRAR NA SALA"},
		{"id": "back", "label": "VOLTAR"},
	]
