# 24 — Clone fantasma

**Fase:** 3 · **Tiles:** `y` (ponto de gravação) / `Y` (sensor) · **Custo:** alto

## 1. O que é

O jogador atravessa um ponto de gravação; a partir dali, seus movimentos são
registrados. Ao chegar num segundo ponto (ou depois de N segundos), um clone
nasce no ponto inicial e **repete exatamente o que foi gravado**. O clone tem
corpo: pisa em sensores `Y`, segura interruptores, serve de plataforma.

É a mecânica mais estranha da lista para este jogo, e vale ser explícito sobre
isso: **é uma mecânica de puzzle dentro de um jogo de precisão**. As duas coisas
convivem (Celeste tem salas de puzzle), mas o ritmo muda — sala de clone se
resolve pensando, não executando, e depois se executa a solução.

Consequência prática: as salas de clone são as únicas em que **o par de tempo
não deve valer medalha** (passo 08), porque o primeiro contato com elas é
inevitavelmente lento. Ou isso, ou o par é calculado para quem já sabe a
solução — o que pune a descoberta.

## 2. Salas novas no modo história — 4

Um capítulo próprio, isolado, depois do eco (passo 23) se ele existir.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `clone_first` — SOMBRA | que o clone repete | Sensor `Y` que abre a porta, e a porta fecha quando o sensor solta. O clone tem que ficar em cima dele. |
| 2 | `clone_step` — DEGRAU VIVO | clone como plataforma | Plataforma alta demais; a gravação é o clone parado no lugar certo e o jogador pulando em cima dele. |
| 3 | `clone_two` — DOIS SENSORES | duas gravações | Dois `y`, dois clones, dois sensores simultâneos. |
| 4 | `clone_race` — SINCRONIA | clone e jogador em rotas paralelas | O clone segura um `Y` que abre uma passagem por 3 s; o jogador precisa estar do outro lado nesse intervalo. |

```gdscript
## Um sensor, uma porta, um clone. A sala é a frase inteira.
static func _level_clone_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	put(g, 12, 26, "y")                  # ponto de gravação
	put(g, 24, 26, "Y")                  # sensor que o clone precisa segurar
	rect(g, 40, 20, 2, 7, "g")           # porta comandada (passo 12)
	puts(g, [Vector2i(32, 25), Vector2i(46, 25), Vector2i(50, 22)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)
```

**Depende do passo 12** (portas comandadas) para as salas 1 e 4 fazerem sentido.
Implementar depois dele, não antes.

**Par sugerido:** sem medalha de tempo. Se houver par: 60 s, 75 s, 80 s, 90 s.

## 3. Modo infinito

**Não incluir, sem exceção prevista.**

Uma sala de puzzle no meio de uma corrida quebra o único contrato do modo
infinito: que a próxima sala é do mesmo tipo de desafio que a anterior, só mais
difícil. Um enigma na profundidade 14 não é mais difícil — é outra coisa, e
interrompe a run.

## 4. Codex

```gdscript
{"id": "clone", "kind": ABILITY, "sprite": "icon_clone"},
{"id": "sensor", "kind": WORLD, "sprite": "sensor_off"},
"y": "clone", "Y": "sensor",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `GHOST CLONE` | `IT REPLAYS WHAT YOU JUST DID. IT HAS A BODY` |
| PT | `CLONE FANTASMA` | `ELE REPETE O QUE VOCE ACABOU DE FAZER. TEM CORPO` |
| ES | `CLON FANTASMA` | `REPITE LO QUE ACABAS DE HACER. TIENE CUERPO` |
| EN | `SENSOR` | `IT NEEDS WEIGHT ON IT. YOURS OR SOMEONE ELSES` |
| PT | `SENSOR` | `PRECISA DE PESO EM CIMA. SEU OU DE OUTRO` |
| ES | `SENSOR` | `NECESITA PESO ENCIMA. TUYO O DE OTRO` |

**Visual:** o clone é o sprite do player em `Palette.PURPLE` com 60 % de
opacidade e um rastro. Durante a gravação, um indicador na tela mostra o tempo
restante — sem ele o jogador não sabe quando parar de gravar, e a sala vira
tentativa e erro.

## 5. Para o agente

**Gravar entrada, não posição.** Duas abordagens:

| | Grava | Reproduz | Problema |
| --- | --- | --- | --- |
| A | `Vector2` por frame | seta `global_position` | clone atravessa paredes que mudaram; barato e previsível |
| B | estado do input por frame | roda a física do player | determinismo exige que nada externo interfira |

**Recomendação: A.** O determinismo de B é frágil — basta uma plataforma móvel
com fase diferente e o clone dessincroniza, e o jogador vê a solução que
funcionou ontem falhar hoje. Gravar posição é literal e sempre reproduz.

```gdscript
# clone.gd
const RECORD_HZ := 60
var _frames: PackedVector2Array
var _at := 0

func _physics_process(_delta: float) -> void:
	if _at >= _frames.size():
		queue_free()
		return
	position = _frames[_at]
	_at += 1
```

O corpo é um `AnimatableBody2D` com `sync_to_physics` (para carregar o player,
sala 2) mais uma `Area2D` para os sensores.

**Arquivos:** `scripts/clone.gd`, `scripts/record_pad.gd`, `scripts/sensor.gd`,
`level.gd` (orquestra a gravação, que é estado da sala), `player.gd` (nada, se
a abordagem for A), `pixel_art.gd`, `codex.gd`, `i18n.gd`, `levels.gd`.

**Armadilhas**
- **O clone é sólido para o player** (sala 2 depende disso), o que significa que
  ele pode prensar o jogador contra uma parede. Regra: o clone **não** empurra;
  se o player estiver no caminho, o clone passa por dentro (colisão só no topo,
  como uma plataforma one-way). Isso resolve prensa e mantém o uso de degrau.
- Memória: 60 Hz × 10 s = 600 `Vector2` = 4,8 KB por clone. Irrelevante, mas
  limitar a gravação a ~12 s evita salas com clones de um minuto.
- `restart()` precisa apagar clones e gravações. Como tudo vive em `_entities`,
  o `restart()` atual já resolve — conferir que o estado de gravação em `Level`
  também zera.
- Sensor pressionado pelo clone e pelo jogador ao mesmo tempo: contar peso, não
  booleano, para o caso de dois sensores em série.
- Nunca deixar a sala travar num estado sem solução com o clone já gasto. Ou o
  ponto `y` é reutilizável, ou a sala precisa de reinício explícito — e "morrer
  para reiniciar" não pode ser a resposta, porque nessas salas o jogador pode
  não ter como morrer. Botão de reiniciar sala (R) já existe e resolve, mas
  precisa estar visível no HUD dessas salas.

**Critérios de aceite**
- O clone reproduz o trajeto gravado quadro a quadro.
- Player pode subir no clone; clone nunca prende o player.
- Reiniciar limpa clones e gravação.
- Nenhuma das 4 salas pode chegar a um estado sem saída.
