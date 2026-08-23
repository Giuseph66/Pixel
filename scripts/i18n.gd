extends Node

## Autoload. Every string the player ever reads lives here.
##
## Lookups are plain dictionary hits keyed by a dotted id. A missing key falls
## back to English and, failing that, to the key itself — a screen never blanks
## out because a translation is short.
##
## The bitmap font is uppercase only, so the tables are written in uppercase.
## Accented capitals are drawn by PixelFont; keep new text to the glyphs it has.

signal changed

const DEFAULT := "en"
const ORDER := ["en", "pt", "es"]

const NAMES := {
	"en": "ENGLISH",
	"pt": "PORTUGUÊS",
	"es": "ESPAÑOL",
}

var code := DEFAULT


func _ready() -> void:
	var saved := str(Save.data.get("lang", ""))
	set_lang(saved if STRINGS.has(saved) else detect())


## Best guess from the system locale, used the first time the game runs.
static func detect() -> String:
	var locale := OS.get_locale().to_lower()
	for id: String in ORDER:
		if locale.begins_with(id):
			return id
	return DEFAULT


func set_lang(id: String) -> void:
	if not STRINGS.has(id):
		id = DEFAULT
	if id == code:
		return
	code = id
	changed.emit()


## Step to the next language in ORDER and persist the choice.
func cycle(step: int = 1) -> void:
	var i := ORDER.find(code)
	set_lang(ORDER[wrapi(i + step, 0, ORDER.size())])
	Save.set_lang(code)


func language_name() -> String:
	return NAMES.get(code, code.to_upper())


## Translate `key`. Unknown keys come back unchanged, which keeps them visible.
func t(key: String) -> String:
	var table: Dictionary = STRINGS[code]
	if table.has(key):
		return table[key]
	var english: Dictionary = STRINGS[DEFAULT]
	return english.get(key, key)


## t() with printf arguments, e.g. tf("hud.gems", [taken, total]).
func tf(key: String, args: Array) -> String:
	return t(key) % args


# ---------------------------------------------------------------- tables ---

const STRINGS := {
"en": {
	"ui.on": "ON",
	"ui.off": "OFF",

	"title.footer": "ARROWS TO CHOOSE, SPACE TO CONFIRM",
	"title.play": "PLAY",
	"title.levels": "LEVELS",
	"title.music": "MUSIC",
	"title.sfx": "SOUND",
	"title.language": "LANGUAGE",
	"title.quit": "QUIT",
	"title.stats": "%d / %d ROOMS CLEARED   %d GEMS",

	"select.title": "SELECT A ROOM",
	"select.footer": "SPACE TO PLAY, ESC TO GO BACK",
	"select.locked": "LOCKED",
	"select.time": "TIME ",
	"select.gems": "GEMS %d/%d",

	"hud.gems": "GEMS %d/%d",

	"pause.title": "PAUSED",
	"pause.footer": "ESC TO RESUME",
	"pause.resume": "RESUME",
	"pause.restart": "RESTART ROOM",
	"pause.rooms": "ROOMS",
	"pause.menu": "TITLE",

	"results.title": "ROOM CLEAR",
	"results.footer": "SPACE TO CONFIRM",
	"results.time": "TIME",
	"results.best": "BEST",
	"results.gems": "GEMS",
	"results.deaths": "DEATHS",
	"results.record": "NEW RECORD",
	"results.under_par": "UNDER PAR %s",
	"results.next": "NEXT ROOM",
	"results.retry": "RETRY",
	"results.rooms": "ROOMS",
	"results.finish": "FINISH",

	"ending.title": "ALL ROOMS CLEAR",
	"ending.subtitle": "THANKS FOR PLAYING",
	"ending.total_time": "TOTAL TIME",
	"ending.gems": "GEMS",
	"ending.deaths": "DEATHS",
	"ending.rooms": "ROOMS",
	"ending.menu": "TITLE",

	"level.1.name": "FIRST STEPS",
	"level.1.hint": "ARROWS OR A/D TO MOVE, SPACE TO JUMP",
	"level.2.name": "MIND THE GAP",
	"level.2.hint": "HOLD JUMP LONGER TO JUMP HIGHER",
	"level.3.name": "PRICKLY",
	"level.3.hint": "PRESS R TO RESTART INSTANTLY",
	"level.4.name": "SLIME TIME",
	"level.4.hint": "LAND ON A SLIME TO SQUASH IT",
	"level.5.name": "BOUNCE",
	"level.5.hint": "SPRINGS THROW YOU WAY ABOVE A NORMAL JUMP",
	"level.6.name": "THE CLIMB",
	"level.6.hint": "SLIDE DOWN A WALL, THEN JUMP OFF IT",
},

"pt": {
	"ui.on": "LIGADO",
	"ui.off": "DESLIGADO",

	"title.footer": "SETAS PARA ESCOLHER, ESPAÇO PARA CONFIRMAR",
	"title.play": "JOGAR",
	"title.levels": "SALAS",
	"title.music": "MÚSICA",
	"title.sfx": "SOM",
	"title.language": "IDIOMA",
	"title.quit": "SAIR",
	"title.stats": "%d / %d SALAS CONCLUÍDAS   %d GEMAS",

	"select.title": "ESCOLHA UMA SALA",
	"select.footer": "ESPAÇO PARA JOGAR, ESC PARA VOLTAR",
	"select.locked": "TRANCADA",
	"select.time": "TEMPO ",
	"select.gems": "GEMAS %d/%d",

	"hud.gems": "GEMAS %d/%d",

	"pause.title": "PAUSADO",
	"pause.footer": "ESC PARA CONTINUAR",
	"pause.resume": "CONTINUAR",
	"pause.restart": "REINICIAR SALA",
	"pause.rooms": "SALAS",
	"pause.menu": "MENU",

	"results.title": "SALA CONCLUÍDA",
	"results.footer": "ESPAÇO PARA CONFIRMAR",
	"results.time": "TEMPO",
	"results.best": "MELHOR",
	"results.gems": "GEMAS",
	"results.deaths": "MORTES",
	"results.record": "NOVO RECORDE",
	"results.under_par": "ABAIXO DO PAR %s",
	"results.next": "PRÓXIMA SALA",
	"results.retry": "DE NOVO",
	"results.rooms": "SALAS",
	"results.finish": "TERMINAR",

	"ending.title": "TODAS CONCLUÍDAS",
	"ending.subtitle": "OBRIGADO POR JOGAR",
	"ending.total_time": "TEMPO TOTAL",
	"ending.gems": "GEMAS",
	"ending.deaths": "MORTES",
	"ending.rooms": "SALAS",
	"ending.menu": "MENU",

	"level.1.name": "PRIMEIROS PASSOS",
	"level.1.hint": "SETAS OU A/D PARA MOVER, ESPAÇO PARA PULAR",
	"level.2.name": "CUIDADO COM O VÃO",
	"level.2.hint": "SEGURE O PULO PARA PULAR MAIS ALTO",
	"level.3.name": "ESPINHOS",
	"level.3.hint": "APERTE R PARA REINICIAR NA HORA",
	"level.4.name": "HORA DA GOSMA",
	"level.4.hint": "CAIA EM CIMA DA GOSMA PARA ESMAGAR",
	"level.5.name": "SALTO",
	"level.5.hint": "MOLAS TE JOGAM BEM MAIS ALTO QUE UM PULO",
	"level.6.name": "A ESCALADA",
	"level.6.hint": "DESLIZE NA PAREDE, DEPOIS PULE DELA",
},

"es": {
	"ui.on": "ACTIVADO",
	"ui.off": "APAGADO",

	"title.footer": "FLECHAS PARA ELEGIR, ESPACIO PARA CONFIRMAR",
	"title.play": "JUGAR",
	"title.levels": "SALAS",
	"title.music": "MÚSICA",
	"title.sfx": "SONIDO",
	"title.language": "IDIOMA",
	"title.quit": "SALIR",
	"title.stats": "%d / %d SALAS COMPLETADAS   %d GEMAS",

	"select.title": "ELIGE UNA SALA",
	"select.footer": "ESPACIO PARA JUGAR, ESC PARA VOLVER",
	"select.locked": "BLOQUEADA",
	"select.time": "TIEMPO ",
	"select.gems": "GEMAS %d/%d",

	"hud.gems": "GEMAS %d/%d",

	"pause.title": "PAUSA",
	"pause.footer": "ESC PARA SEGUIR",
	"pause.resume": "CONTINUAR",
	"pause.restart": "REINICIAR SALA",
	"pause.rooms": "SALAS",
	"pause.menu": "MENU",

	"results.title": "SALA COMPLETA",
	"results.footer": "ESPACIO PARA CONFIRMAR",
	"results.time": "TIEMPO",
	"results.best": "MEJOR",
	"results.gems": "GEMAS",
	"results.deaths": "MUERTES",
	"results.record": "NUEVO RÉCORD",
	"results.under_par": "BAJO EL PAR %s",
	"results.next": "SIGUIENTE SALA",
	"results.retry": "REINTENTAR",
	"results.rooms": "SALAS",
	"results.finish": "TERMINAR",

	"ending.title": "TODAS COMPLETAS",
	"ending.subtitle": "GRACIAS POR JUGAR",
	"ending.total_time": "TIEMPO TOTAL",
	"ending.gems": "GEMAS",
	"ending.deaths": "MUERTES",
	"ending.rooms": "SALAS",
	"ending.menu": "MENU",

	"level.1.name": "PRIMEROS PASOS",
	"level.1.hint": "FLECHAS O A/D PARA MOVER, ESPACIO PARA SALTAR",
	"level.2.name": "CUIDADO CON EL HUECO",
	"level.2.hint": "MANTÉN EL SALTO PARA SALTAR MÁS ALTO",
	"level.3.name": "ESPINAS",
	"level.3.hint": "PULSA R PARA REINICIAR AL INSTANTE",
	"level.4.name": "HORA DEL LIMO",
	"level.4.hint": "CAE SOBRE UN LIMO PARA APLASTARLO",
	"level.5.name": "REBOTE",
	"level.5.hint": "LOS RESORTES TE LANZAN MUY POR ENCIMA",
	"level.6.name": "LA ESCALADA",
	"level.6.hint": "DESLÍZATE POR UN MURO, LUEGO SALTA DE ÉL",
},
}
