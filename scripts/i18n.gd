extends Node

## Autoload. Every string the player ever reads lives here.
##
## Lookups are plain dictionary hits keyed by a dotted id. A missing key falls
## back to English and, failing that, to the key itself — a screen never blanks
## out because a translation is short.
##
## The bitmap font is uppercase only, so the tables are written in uppercase.
## Portuguese and Spanish are written without accents on purpose — the
## de-accented word is still readable, and it sidesteps the font entirely
## rather than betting every new string on accented glyphs staying correct.

signal changed

const DEFAULT := "en"
const ORDER := ["en", "pt", "es"]

const NAMES := {
	"en": "ENGLISH",
	"pt": "PORTUGUES",
	"es": "ESPANOL",
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

	"title.options": "OPTIONS",
	"options.title": "OPTIONS",
	"options.footer": "SPACE TO CHANGE, ESC TO GO BACK",
	"options.back": "BACK",

	"play.title": "CHOOSE A MODE",
	"play.footer": "ARROWS TO CHOOSE, SPACE TO CONFIRM, ESC TO GO BACK",
	"play.story": "STORY",
	"play.story_new": "NOT STARTED",
	"play.story_progress": "%d / %d ROOMS",
	"play.story_gems": "%d GEMS",
	"play.endless": "ENDLESS",
	"play.endless_new": "NEVER PLAYED",
	"play.endless_best": "BEST %d ROOMS",

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
	"level.13.name": "FIRST DASH",
	"level.13.hint": "SHIFT TO DASH THROUGH THE AIR, ONCE PER JUMP",
	"level.14.name": "CRYSTAL CHAIN",
	"level.14.hint": "A CRYSTAL GIVES THE DASH BACK IN MID AIR",
	"level.15.name": "FERRY",
	"level.15.hint": "THE SLABS CARRY YOU, SO LET THEM",
	"level.16.name": "ON THE BEAT",
	"level.16.hint": "BLOCKS BLINK BEFORE THEY GO. WAIT FOR YOURS",
	"level.17.name": "NEEDLE",
	"level.17.hint": "TOO FAR TO JUMP. GRAB A CRYSTAL AND DASH",
	"level.18.name": "ALL AT ONCE",
	"level.18.hint": "FERRY, BEAT, CRYSTAL, LIFT. IN THAT ORDER",
},

"pt": {
	"ui.on": "LIGADO",
	"ui.off": "DESLIGADO",

	"title.footer": "SETAS PARA ESCOLHER, ESPACO PARA CONFIRMAR",
	"title.play": "JOGAR",
	"title.levels": "SALAS",
	"title.music": "MUSICA",
	"title.sfx": "SOM",
	"title.language": "IDIOMA",
	"title.quit": "SAIR",
	"title.stats": "%d / %d SALAS CONCLUIDAS   %d GEMAS",

	"title.options": "OPCOES",
	"options.title": "OPCOES",
	"options.footer": "ESPACO PARA MUDAR, ESC PARA VOLTAR",
	"options.back": "VOLTAR",

	"play.title": "ESCOLHA UM MODO",
	"play.footer": "SETAS PARA ESCOLHER, ESPACO PARA CONFIRMAR, ESC PARA VOLTAR",
	"play.story": "HISTORIA",
	"play.story_new": "NAO INICIADA",
	"play.story_progress": "%d / %d SALAS",
	"play.story_gems": "%d GEMAS",
	"play.endless": "INFINITO",
	"play.endless_new": "NUNCA JOGADO",
	"play.endless_best": "MELHOR %d SALAS",

	"select.title": "ESCOLHA UMA SALA",
	"select.footer": "ESPACO PARA JOGAR, ESC PARA VOLTAR",
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

	"results.title": "SALA CONCLUIDA",
	"results.footer": "ESPACO PARA CONFIRMAR",
	"results.time": "TEMPO",
	"results.best": "MELHOR",
	"results.gems": "GEMAS",
	"results.deaths": "MORTES",
	"results.record": "NOVO RECORDE",
	"results.under_par": "ABAIXO DO PAR %s",
	"results.next": "PROXIMA SALA",
	"results.retry": "DE NOVO",
	"results.rooms": "SALAS",
	"results.finish": "TERMINAR",

	"ending.title": "TODAS CONCLUIDAS",
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
	"endless.hint": "AS SALAS NASCEM NA HORA. ATE ONDE VOCE VAI?",
	"endless.title": "FIM DA RUN",
	"endless.subtitle": "MODO INFINITO",
	"endless.depth": "SALAS",
	"endless.time": "TEMPO",
	"endless.gems": "GEMAS",
	"endless.deaths": "MORTES",
	"endless.record": "NOVO RECORDE",

	"level.1.name": "PRIMEIROS PASSOS",
	"level.1.hint": "SETAS OU A/D PARA MOVER, ESPACO PARA PULAR",
	"level.2.name": "CUIDADO COM O VAO",
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
	"level.7.hint": "AS PLATAFORMAS DE CIMA SAO O CAMINHO SEGURO",
	"level.8.name": "TRAMPOLIM",
	"level.8.hint": "CADA MOLA FICA EM CIMA DO ANDAR DE BAIXO",
	"level.9.name": "ESCADARIA",
	"level.9.hint": "PULE DIRETO ATRAVES DE UMA PLATAFORMA FINA",
	"level.10.name": "ARMADILHAS",
	"level.10.hint": "O CAMINHO DE CIMA TEM AS GEMAS",
	"level.11.name": "TORRE DE MOLAS",
	"level.11.hint": "DOIS SALTOS DO CHAO ATE O TOPO",
	"level.12.name": "DESAFIO FINAL",
	"level.12.hint": "TUDO QUE VOCE APRENDEU, NUMA SALA SO",
	"level.13.name": "PRIMEIRO DASH",
	"level.13.hint": "SHIFT PARA AVANÇAR NO AR, UMA VEZ POR PULO",
	"level.14.name": "CORRENTE DE CRISTAL",
	"level.14.hint": "O CRISTAL DEVOLVE O DASH NO MEIO DO AR",
	"level.15.name": "BALSA",
	"level.15.hint": "AS PLACAS TE CARREGAM, DEIXE ELAS TRABALHAREM",
	"level.16.name": "NO RITMO",
	"level.16.hint": "OS BLOCOS PISCAM ANTES DE SUMIR. ESPERE O SEU",
	"level.17.name": "AGULHA",
	"level.17.hint": "LONGE DEMAIS PARA PULAR. PEGUE O CRISTAL E AVANCE",
	"level.18.name": "TUDO DE UMA VEZ",
	"level.18.hint": "BALSA, RITMO, CRISTAL, ELEVADOR. NESSA ORDEM",
},

"es": {
	"ui.on": "ACTIVADO",
	"ui.off": "APAGADO",

	"title.footer": "FLECHAS PARA ELEGIR, ESPACIO PARA CONFIRMAR",
	"title.play": "JUGAR",
	"title.levels": "SALAS",
	"title.music": "MUSICA",
	"title.sfx": "SONIDO",
	"title.language": "IDIOMA",
	"title.quit": "SALIR",
	"title.stats": "%d / %d SALAS COMPLETADAS   %d GEMAS",

	"title.options": "OPCIONES",
	"options.title": "OPCIONES",
	"options.footer": "ESPACIO PARA CAMBIAR, ESC PARA VOLVER",
	"options.back": "VOLVER",

	"play.title": "ELIGE UN MODO",
	"play.footer": "FLECHAS PARA ELEGIR, ESPACIO PARA CONFIRMAR, ESC PARA VOLVER",
	"play.story": "HISTORIA",
	"play.story_new": "SIN EMPEZAR",
	"play.story_progress": "%d / %d SALAS",
	"play.story_gems": "%d GEMAS",
	"play.endless": "INFINITO",
	"play.endless_new": "NUNCA JUGADO",
	"play.endless_best": "MEJOR %d SALAS",

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
	"results.record": "NUEVO RECORD",
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
	"endless.hint": "LAS SALAS NACEN AL VUELO. HASTA DONDE LLEGAS?",
	"endless.title": "FIN DE LA RUN",
	"endless.subtitle": "MODO INFINITO",
	"endless.depth": "SALAS",
	"endless.time": "TIEMPO",
	"endless.gems": "GEMAS",
	"endless.deaths": "MUERTES",
	"endless.record": "NUEVO RECORD",

	"level.1.name": "PRIMEROS PASOS",
	"level.1.hint": "FLECHAS O A/D PARA MOVER, ESPACIO PARA SALTAR",
	"level.2.name": "CUIDADO CON EL HUECO",
	"level.2.hint": "MANTEN EL SALTO PARA SALTAR MAS ALTO",
	"level.3.name": "ESPINAS",
	"level.3.hint": "PULSA R PARA REINICIAR AL INSTANTE",
	"level.4.name": "HORA DEL LIMO",
	"level.4.hint": "CAE SOBRE UN LIMO PARA APLASTARLO",
	"level.5.name": "REBOTE",
	"level.5.hint": "LOS RESORTES TE LANZAN MUY POR ENCIMA",
	"level.6.name": "LA ESCALADA",
	"level.6.hint": "DESLIZATE POR UN MURO, LUEGO SALTA DE EL",
	"level.7.name": "SOBRE LOS POZOS",
	"level.7.hint": "LAS PLATAFORMAS DE ARRIBA SON MAS SEGURAS",
	"level.8.name": "TRAMPOLIN",
	"level.8.hint": "CADA RESORTE SE APOYA EN EL NIVEL DE ABAJO",
	"level.9.name": "ESCALERA",
	"level.9.hint": "SALTA HACIA ARRIBA A TRAVES DE UNA PLATAFORMA",
	"level.10.name": "TRAMPAS",
	"level.10.hint": "LA RUTA ALTA GUARDA LAS GEMAS",
	"level.11.name": "TORRE DE RESORTES",
	"level.11.hint": "DOS IMPULSOS DESDE EL SUELO HASTA LA CIMA",
	"level.12.name": "DESAFIO FINAL",
	"level.12.hint": "TODO LO QUE APRENDISTE, EN UNA SALA",
	"level.13.name": "PRIMER DASH",
	"level.13.hint": "SHIFT PARA IMPULSARTE EN EL AIRE, UNA VEZ POR SALTO",
	"level.14.name": "CADENA DE CRISTAL",
	"level.14.hint": "EL CRISTAL DEVUELVE EL DASH EN PLENO AIRE",
	"level.15.name": "BALSA",
	"level.15.hint": "LAS LOSAS TE LLEVAN, DEJA QUE TRABAJEN",
	"level.16.name": "AL COMPÁS",
	"level.16.hint": "LOS BLOQUES PARPADEAN ANTES DE IRSE. ESPERA",
	"level.17.name": "AGUJA",
	"level.17.hint": "DEMASIADO LEJOS PARA SALTAR. CRISTAL Y DASH",
	"level.18.name": "TODO A LA VEZ",
	"level.18.hint": "BALSA, COMPÁS, CRISTAL, ASCENSOR. EN ESE ORDEN",
},
}
