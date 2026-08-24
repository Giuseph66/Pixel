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
	var saved := str(Save.settings.get("lang", ""))
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

	"title.codex": "CODEX",
	"title.saves": "SAVES",

	"codex.title": "CODEX",
	"codex.found": "%d OF %d FOUND",
	"codex.footer": "UP/DOWN CHAPTER, LEFT/RIGHT PAGE, ESC BACK",

	"codex.cat.ability": "ABILITIES",
	"codex.cat.creature": "CREATURES",
	"codex.cat.collectible": "COLLECTIBLES",
	"codex.cat.world": "WORLD",
	"codex.unknown": "NOT FOUND YET",
	"codex.new": "NEW!",

	"codex.run.name": "RUN",
	"codex.run.text": "ARROWS OR A/D. THE ONLY THING YOU ALWAYS HAVE",
	"codex.jump.name": "JUMP",
	"codex.jump.text": "HOLD THE BUTTON LONGER TO GO HIGHER",
	"codex.wall.name": "WALL SLIDE",
	"codex.wall.text": "TOUCH A WALL TO CLING, THEN JUMP OFF IT",
	"codex.stomp.name": "STOMP",
	"codex.stomp.text": "LAND ON AN ENEMY. EACH ONE IN A ROW THROWS HIGHER",
	"codex.dash.name": "DASH",
	"codex.dash.text": "ONE PER JUMP. GROUND, WALL OR CRYSTAL GIVES IT BACK",
	"codex.pound.name": "GROUND POUND",
	"codex.pound.text": "DOWN PLUS JUMP IN THE AIR. BREAKS WHAT IS BELOW",

	"codex.slime.name": "SLIME",
	"codex.slime.text": "WALKS ITS LEDGE AND TURNS AT THE EDGE. STOMPABLE",
	"codex.bat.name": "BAT",
	"codex.bat.text": "OWNS THE AIR ON A SLOW WAVE. STOMPABLE",
	"codex.saw.name": "SAW",
	"codex.saw.text": "KILLS FROM EVERY SIDE. THERE IS NO STOMPING A BLADE",

	"codex.gem.name": "GEM",
	"codex.gem.text": "OPTIONAL. THE DOOR OPENS WITHOUT THEM",
	"codex.door.name": "EXIT",
	"codex.door.text": "WALK IN TO FINISH THE ROOM",
	"codex.spike.name": "SPIKE",
	"codex.spike.text": "KILLS ON TOUCH. THE HITBOX IS SMALLER THAN IT LOOKS",
	"codex.spring.name": "SPRING",
	"codex.spring.text": "THROWS YOU FOURTEEN TILES UP AND REFILLS THE DASH",
	"codex.crystal.name": "CRYSTAL",
	"codex.crystal.text": "GIVES THE DASH BACK IN MID AIR, THEN RECHARGES",
	"codex.crumble.name": "CRUMBLING",
	"codex.crumble.text": "DROPS A MOMENT AFTER YOU STAND ON IT. KEEP MOVING",
	"codex.timed.name": "TIMED BLOCK",
	"codex.timed.text": "ON AND OFF ON A BEAT. IT BLINKS BEFORE IT GOES",
	"codex.breakable.name": "BREAKABLE",
	"codex.breakable.text": "ONLY A GROUND POUND OPENS IT. IT STAYS OPEN",
	"codex.platform.name": "PLATFORM",
	"codex.platform.text": "SLIDES OR RIDES, AND CARRIES YOU WHILE IT DOES",

	"saves.title": "SAVES",
	"saves.footer": "SPACE TO PLAY THIS SLOT, R TO CLEAR IT, ESC TO GO BACK",
	"saves.confirm": "CLEAR THIS SLOT? SPACE TO CONFIRM, ESC TO CANCEL",
	"saves.slot": "RUN %d",
	"saves.active": "IN USE",
	"saves.empty": "EMPTY",
	"saves.rooms": "ROOMS",
	"saves.time": "TIME",
	"saves.gems": "GEMS",
	"saves.endless": "ENDLESS",
	"saves.deaths": "DEATHS",
	"saves.codex": "CODEX",
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
	"level.19.name": "SLAM",
	"level.19.hint": "IN THE AIR, HOLD DOWN AND JUMP TO POUND THROUGH",
	"level.20.name": "CELLAR",
	"level.20.hint": "BREAK IN ANYWHERE. THE HOLE IS ALSO THE WAY OUT",
	"level.21.name": "CHAIN",
	"level.21.hint": "EACH SLIME TAKEN IN A ROW THROWS YOU HIGHER",

	"level.ice_first.name": "SLIPPERY START",
	"level.ice_first.hint": "THE GROUND IS SLIPPERY. PLAN AHEAD",
	"level.ice_edge.name": "SKATING EDGE",
	"level.ice_edge.hint": "DRIFT BETWEEN FROZEN PLATES",
	"level.ice_wall.name": "FROZEN BRAKE",
	"level.ice_wall.hint": "USE THE WALL TO STOP",
	"level.ice_slime.name": "SLIME ON ICE",
	"level.ice_slime.hint": "THEY SLIDE TOO",

	"ice": "ICE",
	"ice.desc": "NO GRIP. STOPPING COSTS GROUND, SO AIM EARLY",
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

	"title.codex": "LIVRO",
	"title.saves": "SAVES",

	"codex.title": "LIVRO",
	"codex.found": "%d DE %d ENCONTRADOS",
	"codex.footer": "CIMA/BAIXO CAPITULO, ESQ/DIR PAGINA, ESC VOLTA",

	"codex.cat.ability": "HABILIDADES",
	"codex.cat.creature": "CRIATURAS",
	"codex.cat.collectible": "COLETAVEIS",
	"codex.cat.world": "MUNDO",
	"codex.unknown": "AINDA NAO ENCONTRADO",
	"codex.new": "NOVO!",

	"codex.run.name": "CORRER",
	"codex.run.text": "SETAS OU A/D. A UNICA COISA QUE VOCE SEMPRE TEM",
	"codex.jump.name": "PULAR",
	"codex.jump.text": "SEGURE O BOTAO MAIS TEMPO PARA IR MAIS ALTO",
	"codex.wall.name": "PAREDE",
	"codex.wall.text": "ENCOSTE PARA GRUDAR, DEPOIS PULE DELA",
	"codex.stomp.name": "PISAO",
	"codex.stomp.text": "CAIA EM CIMA. CADA UM EM SEQUENCIA JOGA MAIS ALTO",
	"codex.dash.name": "DASH",
	"codex.dash.text": "UM POR PULO. CHAO, PAREDE OU CRISTAL DEVOLVE",
	"codex.pound.name": "IMPACTO",
	"codex.pound.text": "BAIXO MAIS PULO NO AR. QUEBRA O QUE ESTA EMBAIXO",

	"codex.slime.name": "GOSMA",
	"codex.slime.text": "ANDA NA PLATAFORMA E VIRA NA BORDA. DA PISAO",
	"codex.bat.name": "MORCEGO",
	"codex.bat.text": "DOMINA O AR EM ONDA LENTA. DA PISAO",
	"codex.saw.name": "SERRA",
	"codex.saw.text": "MATA DE QUALQUER LADO. NAO SE PISA NUMA LAMINA",

	"codex.gem.name": "GEMA",
	"codex.gem.text": "OPCIONAL. A PORTA ABRE MESMO SEM ELAS",
	"codex.door.name": "SAIDA",
	"codex.door.text": "ENTRE NELA PARA TERMINAR A SALA",
	"codex.spike.name": "ESPINHO",
	"codex.spike.text": "MATA NO TOQUE. A AREA E MENOR DO QUE PARECE",
	"codex.spring.name": "MOLA",
	"codex.spring.text": "TE JOGA 14 TILES PARA CIMA E DEVOLVE O DASH",
	"codex.crystal.name": "CRISTAL",
	"codex.crystal.text": "DEVOLVE O DASH NO AR E DEPOIS RECARREGA",
	"codex.crumble.name": "CHAO FRAGIL",
	"codex.crumble.text": "CAI LOGO DEPOIS QUE VOCE PISA. NAO PARE",
	"codex.timed.name": "BLOCO DE RITMO",
	"codex.timed.text": "LIGA E DESLIGA NO COMPASSO. PISCA ANTES DE SUMIR",
	"codex.breakable.name": "QUEBRAVEL",
	"codex.breakable.text": "SO O IMPACTO ABRE. E FICA ABERTO",
	"codex.platform.name": "PLATAFORMA",
	"codex.platform.text": "DESLIZA OU SOBE, E TE CARREGA JUNTO",

	"saves.title": "SAVES",
	"saves.footer": "ESPACO PARA JOGAR, R PARA LIMPAR, ESC PARA VOLTAR",
	"saves.confirm": "LIMPAR ESTE SAVE? ESPACO CONFIRMA, ESC CANCELA",
	"saves.slot": "JOGO %d",
	"saves.active": "EM USO",
	"saves.empty": "VAZIO",
	"saves.rooms": "SALAS",
	"saves.time": "TEMPO",
	"saves.gems": "GEMAS",
	"saves.endless": "INFINITO",
	"saves.deaths": "MORTES",
	"saves.codex": "LIVRO",
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
	"level.13.hint": "SHIFT PARA AVANCAR NO AR, UMA VEZ POR PULO",
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
	"level.19.name": "IMPACTO",
	"level.19.hint": "NO AR, SEGURE BAIXO E PULE PARA QUEBRAR O CHAO",
	"level.20.name": "PORAO",
	"level.20.hint": "ENTRE POR ONDE QUISER. O BURACO TAMBEM E A SAIDA",
	"level.21.name": "CORRENTE",
	"level.21.hint": "CADA GOSMA EM SEQUENCIA TE JOGA MAIS ALTO",

	"level.ice_first.name": "COMECO ESCORREGADIO",
	"level.ice_first.hint": "O CHAO E ESCORREGADIO. PLANEJE ANTES",
	"level.ice_edge.name": "BEIRA GELADA",
	"level.ice_edge.hint": "DESLIZE ENTRE PLACAS CONGELADAS",
	"level.ice_wall.name": "FREIO CONGELADO",
	"level.ice_wall.hint": "USE A PAREDE PARA PARAR",
	"level.ice_slime.name": "GOSMA NO GELO",
	"level.ice_slime.hint": "ELAS ESCORREGAM TAMBEM",

	"ice": "GELO",
	"ice.desc": "SEM ATRITO. PARAR CUSTA CHAO. MIRE ANTES",
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

	"title.codex": "LIBRO",
	"title.saves": "PARTIDAS",

	"codex.title": "LIBRO",
	"codex.found": "%d DE %d ENCONTRADOS",
	"codex.footer": "ARRIBA/ABAJO CAPITULO, IZQ/DER PAGINA, ESC VOLVER",

	"codex.cat.ability": "HABILIDADES",
	"codex.cat.creature": "CRIATURAS",
	"codex.cat.collectible": "COLECCIONABLES",
	"codex.cat.world": "MUNDO",
	"codex.unknown": "AUN NO ENCONTRADO",
	"codex.new": "NUEVO!",

	"codex.run.name": "CORRER",
	"codex.run.text": "FLECHAS O A/D. LO UNICO QUE SIEMPRE TIENES",
	"codex.jump.name": "SALTAR",
	"codex.jump.text": "MANTEN EL BOTON MAS TIEMPO PARA SUBIR MAS",
	"codex.wall.name": "PARED",
	"codex.wall.text": "TOCA LA PARED PARA AGARRARTE Y SALTA DE ELLA",
	"codex.stomp.name": "PISOTON",
	"codex.stomp.text": "CAE ENCIMA. CADA UNO SEGUIDO TE LANZA MAS ALTO",
	"codex.dash.name": "DASH",
	"codex.dash.text": "UNO POR SALTO. SUELO, PARED O CRISTAL LO DEVUELVE",
	"codex.pound.name": "IMPACTO",
	"codex.pound.text": "ABAJO MAS SALTO EN EL AIRE. ROMPE LO DE ABAJO",

	"codex.slime.name": "LIMO",
	"codex.slime.text": "ANDA POR SU BORDE Y GIRA AL FINAL. SE PISA",
	"codex.bat.name": "MURCIELAGO",
	"codex.bat.text": "DOMINA EL AIRE EN ONDA LENTA. SE PISA",
	"codex.saw.name": "SIERRA",
	"codex.saw.text": "MATA POR CUALQUIER LADO. UNA HOJA NO SE PISA",

	"codex.gem.name": "GEMA",
	"codex.gem.text": "OPCIONAL. LA PUERTA ABRE SIN ELLAS",
	"codex.door.name": "SALIDA",
	"codex.door.text": "ENTRA PARA TERMINAR LA SALA",
	"codex.spike.name": "PINCHO",
	"codex.spike.text": "MATA AL TOCAR. EL AREA ES MENOR DE LO QUE PARECE",
	"codex.spring.name": "RESORTE",
	"codex.spring.text": "TE LANZA 14 CASILLAS Y DEVUELVE EL DASH",
	"codex.crystal.name": "CRISTAL",
	"codex.crystal.text": "DEVUELVE EL DASH EN EL AIRE Y LUEGO RECARGA",
	"codex.crumble.name": "SUELO FRAGIL",
	"codex.crumble.text": "CAE JUSTO DESPUES DE PISARLO. NO TE PARES",
	"codex.timed.name": "BLOQUE RITMICO",
	"codex.timed.text": "SE ENCIENDE Y APAGA. PARPADEA ANTES DE IRSE",
	"codex.breakable.name": "ROMPIBLE",
	"codex.breakable.text": "SOLO EL IMPACTO LO ABRE. Y QUEDA ABIERTO",
	"codex.platform.name": "PLATAFORMA",
	"codex.platform.text": "SE DESLIZA O SUBE, Y TE LLEVA CONSIGO",

	"saves.title": "PARTIDAS",
	"saves.footer": "ESPACIO PARA JUGAR, R PARA BORRAR, ESC PARA VOLVER",
	"saves.confirm": "BORRAR ESTA PARTIDA? ESPACIO CONFIRMA, ESC CANCELA",
	"saves.slot": "JUEGO %d",
	"saves.active": "EN USO",
	"saves.empty": "VACIO",
	"saves.rooms": "SALAS",
	"saves.time": "TIEMPO",
	"saves.gems": "GEMAS",
	"saves.endless": "INFINITO",
	"saves.deaths": "MUERTES",
	"saves.codex": "LIBRO",
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
	"level.16.name": "AL COMPAS",
	"level.16.hint": "LOS BLOQUES PARPADEAN ANTES DE IRSE. ESPERA",
	"level.17.name": "AGUJA",
	"level.17.hint": "DEMASIADO LEJOS PARA SALTAR. CRISTAL Y DASH",
	"level.18.name": "TODO A LA VEZ",
	"level.18.hint": "BALSA, COMPAS, CRISTAL, ASCENSOR. EN ESE ORDEN",
	"level.19.name": "IMPACTO",
	"level.19.hint": "EN EL AIRE, ABAJO Y SALTO PARA ROMPER EL SUELO",
	"level.20.name": "SOTANO",
	"level.20.hint": "ENTRA POR DONDE QUIERAS. EL HUECO TAMBIEN ES SALIDA",
	"level.21.name": "CADENA",
	"level.21.hint": "CADA LIMO SEGUIDO TE LANZA MAS ALTO",

	"level.ice_first.name": "COMIENZO RESBALADIZO",
	"level.ice_first.hint": "EL SUELO RESBALA. PLANIFICA ANTES",
	"level.ice_edge.name": "BORDE HELADO",
	"level.ice_edge.hint": "DESLIZA ENTRE PLACAS CONGELADAS",
	"level.ice_wall.name": "FRENO CONGELADO",
	"level.ice_wall.hint": "USA LA PARED PARA FRENAR",
	"level.ice_slime.name": "LIMO EN HIELO",
	"level.ice_slime.hint": "ELLOS TAMBIEN RESBALAN",

	"ice": "HIELO",
	"ice.desc": "SIN AGARRE. FRENAR CUESTA SUELO. APUNTA ANTES",
},
}
