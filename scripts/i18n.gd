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
	"title.endless": "ENDLESS",
	"title.endless_best": "BEST %d",

	"results.continue": "CONTINUE",
	"results.end_run": "END RUN",
	"pause.end_run": "END RUN",

	"endless.room": "ROOM %d",
	"endless.hint": "ROOMS ARE BUILT AS YOU GO. HOW DEEP CAN YOU GET?",
	"endless.title": "RUN OVER",
	"endless.subtitle": "ENDLESS MODE",
	"endless.depth": "ROOMS",
	"endless.time": "TIME",
	"endless.gems": "GEMS",
	"endless.deaths": "DEATHS",
	"endless.record": "NEW BEST",

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
	"level.7.name": "OVER THE PITS",
	"level.7.hint": "THE LEDGES ABOVE ARE THE SAFER WAY ACROSS",
	"level.8.name": "SPRINGBOARD",
	"level.8.hint": "EACH SPRING STANDS ON THE TIER BELOW IT",
	"level.9.name": "STAIRWAY",
	"level.9.hint": "JUMP STRAIGHT UP THROUGH A THIN PLATFORM",
	"level.10.name": "TRAPWAY",
	"level.10.hint": "THE HIGH ROUTE HOLDS THE GEMS",
	"level.11.name": "SPRING TOWER",
	"level.11.hint": "TWO LAUNCHES FROM THE FLOOR TO THE TOP",
	"level.12.name": "GAUNTLET",
	"level.12.hint": "EVERYTHING YOU HAVE LEARNED, IN ONE ROOM",
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
	"title.endless": "INFINITO",
	"title.endless_best": "MELHOR %d",

	"results.continue": "CONTINUAR",
	"results.end_run": "ENCERRAR",
	"pause.end_run": "ENCERRAR RUN",

	"endless.room": "SALA %d",
	"endless.hint": "AS SALAS NASCEM NA HORA. ATÉ ONDE VOCÊ VAI?",
	"endless.title": "FIM DA RUN",
	"endless.subtitle": "MODO INFINITO",
	"endless.depth": "SALAS",
	"endless.time": "TEMPO",
	"endless.gems": "GEMAS",
	"endless.deaths": "MORTES",
	"endless.record": "NOVO RECORDE",

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
	"level.7.name": "SOBRE OS BURACOS",
	"level.7.hint": "AS PLATAFORMAS DE CIMA SÃO O CAMINHO SEGURO",
	"level.8.name": "TRAMPOLIM",
	"level.8.hint": "CADA MOLA FICA EM CIMA DO ANDAR DE BAIXO",
	"level.9.name": "ESCADARIA",
	"level.9.hint": "PULE DIRETO ATRAVÉS DE UMA PLATAFORMA FINA",
	"level.10.name": "ARMADILHAS",
	"level.10.hint": "O CAMINHO DE CIMA TEM AS GEMAS",
	"level.11.name": "TORRE DE MOLAS",
	"level.11.hint": "DOIS SALTOS DO CHÃO ATÉ O TOPO",
	"level.12.name": "DESAFIO FINAL",
	"level.12.hint": "TUDO QUE VOCÊ APRENDEU, NUMA SALA SÓ",
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
	"title.endless": "INFINITO",
	"title.endless_best": "MEJOR %d",

	"results.continue": "CONTINUAR",
	"results.end_run": "TERMINAR",
	"pause.end_run": "TERMINAR RUN",

	"endless.room": "SALA %d",
	"endless.hint": "LAS SALAS NACEN AL VUELO. HASTA DÓNDE LLEGAS?",
	"endless.title": "FIN DE LA RUN",
	"endless.subtitle": "MODO INFINITO",
	"endless.depth": "SALAS",
	"endless.time": "TIEMPO",
	"endless.gems": "GEMAS",
	"endless.deaths": "MUERTES",
	"endless.record": "NUEVO RÉCORD",

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
	"level.7.name": "SOBRE LOS POZOS",
	"level.7.hint": "LAS PLATAFORMAS DE ARRIBA SON MÁS SEGURAS",
	"level.8.name": "TRAMPOLÍN",
	"level.8.hint": "CADA RESORTE SE APOYA EN EL NIVEL DE ABAJO",
	"level.9.name": "ESCALERA",
	"level.9.hint": "SALTA HACIA ARRIBA A TRAVÉS DE UNA PLATAFORMA",
	"level.10.name": "TRAMPAS",
	"level.10.hint": "LA RUTA ALTA GUARDA LAS GEMAS",
	"level.11.name": "TORRE DE RESORTES",
	"level.11.hint": "DOS IMPULSOS DESDE EL SUELO HASTA LA CIMA",
	"level.12.name": "DESAFÍO FINAL",
	"level.12.hint": "TODO LO QUE APRENDISTE, EN UNA SALA",
},
}
