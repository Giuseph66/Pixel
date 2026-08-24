# 21 — Blocos-fantasma

**Fase:** 2 · **Tiles:** `h` (sólido parado) / `H` (sólido em movimento) · **Custo:** médio

## 1. O que é

Blocos cuja solidez depende do **estado de movimento do player**. `h` é sólido
enquanto o player está praticamente parado e some quando ele se move; `H` faz o
contrário.

O custo real deste passo não é código — são ~40 linhas — é **comunicação**. A
regra é invisível: nada na tela explica por que a plataforma sumiu, e um jogador
que não entende a causa conclui que o jogo está quebrado. Por isso este é o
último item da Fase 2, e por isso metade da descrição abaixo é sobre feedback.

```gdscript
# ghost_block.gd
const MOVING := 18.0            # px/s: acima disso o player conta como em movimento
const HYSTERESIS := 6.0         # margem para o bloco não piscar no limiar
```

A histerese não é opcional. Sem ela, um player oscilando em torno de 18 px/s
faz o bloco piscar a 60 Hz, o que além de feio pode matar por sobreposição.

## 2. Salas novas no modo história — 4

No fim da campanha, depois de todas as outras mecânicas de ritmo — o jogador
precisa já confiar que o jogo é justo antes de encontrar uma regra desta.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `ghost_first` — PARADO | a regra `h`, sem risco | Um único bloco `h` sobre chão firme: parar em cima dele funciona, andar faz ele sumir e o player cai 1 tile. Nada mais. |
| 2 | `ghost_move` — EM MOVIMENTO | a regra `H` | Corredor de `H` atravessável só correndo; parar no meio derruba num chão 2 tiles abaixo. |
| 3 | `ghost_mix` — ALTERNADO | as duas juntas | Escada alternando `h` e `H`: sobe-se com paradas e arrancadas ritmadas. |
| 4 | `ghost_gems` — TRES ESTADOS | a regra como enigma | Três gemas, cada uma atrás de um estado diferente (parado, correndo, no ar). |

```gdscript
## Um bloco, chão firme embaixo. Sumir aqui custa um tile de queda e nada mais.
static func _level_ghost_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 26, 26, 6, 1, "h")
	put(g, 29, 24, "o")
	put(g, 4, 26, "P")
	put(g, 52, 26, "X")
	return bake(g)
```

**Par sugerido:** 26 s, 40 s, 52 s, 58 s.

## 3. Modo infinito

**Recomendação: entrar só depois de o passo estar validado na campanha.**

Quando entrar:

```gdscript
## Uma faixa de blocos que só existe para quem está correndo. No infinito o
## jogador está sempre correndo, então este segmento é quase de graça — e é
## essa a intenção: variedade visual e uma armadilha para quem hesita.
static func _ghost(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(8, 11), room)
	Levels.rect(g, x + 2, FLOOR, w - 4, 3, ".")
	Levels.rect(g, x + 2, FLOOR + 3, w - 4, 1, "^")
	Levels.rect(g, x + 2, FLOOR - 1, w - 4, 1, "H")
	spots.append(Vector2i(x + w / 2, FLOOR - 3))
	return w
```

| Tabela | Valor |
| --- | --- |
| `UNLOCK["ghost"]` | 17 |
| `THREAT["ghost"]` | 3.5 |
| `WIDTHS["ghost"]` | 8 |
| `TASTE["ghost"]` | 1.3 (baixo: é a mecânica mais estranha do conjunto) |

**Impacto:** pune hesitação, que é o mesmo eixo da lava (passo 07). Se os dois
aparecerem na mesma sala funda, a sala vira uma corrida sem opção de leitura.
Proibir a combinação: `ghost` não entra em sala-marco.

## 4. Codex

```gdscript
{"id": "ghost", "kind": WORLD, "sprite": "ghost_solid"},
"h": "ghost", "H": "ghost",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `GHOST BLOCK` | `ONE IS THERE WHEN YOU REST, THE OTHER WHEN YOU RUN` |
| PT | `BLOCO FANTASMA` | `UM EXISTE PARADO, O OUTRO SO CORRENDO` |
| ES | `BLOQUE FANTASMA` | `UNO EXISTE QUIETO, EL OTRO SOLO CORRIENDO` |

**Feedback — a parte que decide se o passo funciona:**
- Dois sprites bem diferentes: `h` com um símbolo de "pausa" (duas barras), `H`
  com setas. O símbolo é o que ensina a regra sem texto.
- Estado intangível **continua visível** como contorno pontilhado, nunca
  invisível. O jogador precisa ver o bloco que não está lá.
- Transição com 0,1 s de fade (`modulate:a`), não corte seco. O olho segue a
  causa.
- Partícula no instante da troca, na cor do estado que entrou.

## 5. Para o agente

**Arquivos**
1. `scripts/ghost_block.gd` — `StaticBody2D` de 1 tile ouvindo o player:

```gdscript
func _physics_process(_delta: float) -> void:
	var speed := absf(_player.velocity.x) + absf(_player.velocity.y) * 0.5
	var moving := speed > (MOVING + HYSTERESIS if not _was_moving else MOVING - HYSTERESIS)
	_was_moving = moving
	_set_solid(moving if inverted else not moving)
```

2. `level.gd` — mesma agregação por run que `_spawn_platforms()` faz, para uma
   faixa de 6 tiles não virar 6 nós.
3. `pixel_art.gd`, `codex.gd`, `i18n.gd`, `levels.gd`, `level_gen.gd`.

**Armadilhas**
- **Solidificar em cima do player.** Mesmo problema do passo 12: se o bloco vira
  sólido onde o jogador está, ele fica preso. Aqui é pior, porque acontece o
  tempo todo. Regra: **um bloco-fantasma nunca solidifica se o player o
  sobrepõe** — ele espera o player sair. Isso é mais permissivo que o passo 12
  (que mata) e é a escolha certa aqui, porque a causa é contínua e não um
  evento telegrafado.
- A velocidade vertical entra com peso 0,5 na conta acima; sem isso, o jogador
  caindo verticalmente conta como "parado" e blocos `H` somem no meio da queda.
  Calibrar em playtest.
- Um bloco `h` no chão, sob os pés de um player parado, some assim que ele anda
  — e o jogador anda pisando nele. Nunca usar `h` como piso de corredor; usar
  como plataforma isolada, com chão embaixo.
- `verify_rooms.py` não modela velocidade do jeito que isto precisa. As salas
  deste passo são validadas à mão.
- Interação com dash: durante o dash a velocidade é 232 px/s, sempre "em
  movimento". Coerente e útil — dash atravessa corredores de `H`.

**Critérios de aceite**
- Nenhum caso de player preso dentro de um bloco em 5 minutos de teste.
- Sem piscar no limiar de velocidade.
- O estado intangível continua visível na tela.
