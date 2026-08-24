# 02 — Esteiras

**Fase:** 1 · **Tiles:** `>` `<` · **Custo:** baixo · **Depende de:** [00](00-infra-superficie-e-tuning.md) §4.1

## 1. O que é

Chão que anda. `>` empurra para a direita, `<` para a esquerda. Não tira o
controle: soma uma velocidade ao alvo horizontal, então correr a favor é mais
rápido e correr contra é possível, só que lento.

É a mecânica de leitura mais direta da lista — a direção está desenhada no
tile — e por isso é a melhor para ensinar que "o chão tem propriedades" antes
de o gelo ou o vento aparecerem.

```gdscript
# player.gd
const CONVEYOR_PUSH := 55.0     # px/s somados ao alvo, ~metade de RUN_SPEED
```

A favor: 112 + 55 = 167 px/s, quase 1,5×. Contra: 57 px/s, andar de pedra.
Parado em cima: 55 px/s, o suficiente para ser carregado até a beirada.

## 2. Salas novas no modo história — 4

Entram logo depois da primeira sala de gelo — o par "chão que escorrega" /
"chão que anda" se explica junto.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `belt_first` — CORRENTE | a direção do tile | Três trechos de `>` alternados com piso normal; nada mata. Gema no fim de cada trecho. |
| 2 | `belt_against` — CONTRAMAO | que dá para andar contra | Corredor de `<` de 14 tiles com a porta do outro lado; a única saída é atravessar contra. |
| 3 | `belt_launch` — ARREMESSO | esteira como impulso | `>` de 10 tiles terminando em buraco de 6 com `^`; só a favor o pulo cruza. |
| 4 | `belt_mix` — TRIAGEM | esteiras opostas + inimigo | Faixas de `>` e `<` intercaladas de 4 tiles com dois `S`; a esteira também move o slime? **Não** — ver armadilhas. |

```gdscript
## A esteira lança: o buraco só é cruzável com o empurrão a favor.
static func _level_belt_launch() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 12, 27, 10, 1, ">")
	rect(g, 24, 27, 6, 3, ".")           # o vão
	rect(g, 24, 30, 6, 1, "^")
	rect(g, 34, 27, 8, 1, ">")
	puts(g, [Vector2i(20, 24), Vector2i(40, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 52, 26, "X")
	return bake(g)
```

**Par sugerido:** 20 s, 30 s, 32 s, 42 s.

## 3. Modo infinito

Dois usos, um segmento só:

```gdscript
## Uma faixa de esteira. Metade das vezes ela aponta para a saída (atalho),
## metade para trás (pedágio). As duas leituras são justas porque a direção
## está no sprite.
static func _belt(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(6, 10), room)
	var ch := ">" if rng.randf() < 0.55 else "<"
	Levels.rect(g, x, FLOOR, w, 1, ch)
	spots.append(Vector2i(x + w / 2, STAND - 3))
	return w
```

| Tabela | Valor |
| --- | --- |
| `UNLOCK["belt"]` | 5 |
| `THREAT["belt"]` | 1.5 |
| `WIDTHS["belt"]` | 6 |
| `TASTE["belt"]` | 1.4 |

**Impacto:** `<` antes de um `pit` é a combinação mais dura (o pulo sai curto);
até `depth >= 10`, forçar `>` quando o segmento seguinte já for um vão. Como o
`_pick()` escolhe o próximo segmento só depois de pintar este, o jeito simples
é o contrário: proibir `pit`/`beat` logo após um `belt` esquerdo, checando
`previous`.

## 4. Codex

```gdscript
{"id": "belt", "kind": WORLD, "sprite": "belt_a"},
">": "belt", "<": "belt",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `BELT` | `THE FLOOR MOVES. WITH IT YOU FLY, AGAINST IT YOU CRAWL` |
| PT | `ESTEIRA` | `O CHAO ANDA. A FAVOR VOA, CONTRA ARRASTA` |
| ES | `CINTA` | `EL SUELO ANDA. A FAVOR VUELAS, EN CONTRA ARRASTRAS` |

**Sprite:** duas frames (`belt_a`, `belt_b`) com as setas deslocadas de 2 px,
alternando a ~6 Hz. Como o terreno é assado uma vez em `_bake_terrain()`, a
esteira **não pode** ser terreno assado: ela precisa ser uma entidade
`Sprite2D` animada sobre um tile sólido comum. Ver §5.

## 5. Para o agente

**Decisão de arquitetura, tomada:** a esteira é `#` no baking de colisão e uma
entidade leve por cima, exatamente como `TimedBlock` faz com o próprio sprite.
Isso evita mexer no assado do terreno e dá a animação de graça.

1. `pixel_art.gd` — `belt_a`, `belt_b`.
2. `level.gd`
   - `is_solid()`/`is_ground()` aceitam `>` e `<`.
   - `_bake_terrain()` pinta esses tiles como `#` (sem seta).
   - `_spawn_entities()` cria uma `Conveyor` por run de tiles iguais, como
     `_spawn_platforms()` já faz com `m`/`n` — uma entidade por faixa, não por
     tile, senão uma faixa de 10 vira 10 nós.
3. `scripts/conveyor.gd` — `Node2D` com sprite tileado e uma `Area2D` rasa
   (altura 4 px, colada no topo) que chama `player.push()`:

```gdscript
func _physics_process(_delta: float) -> void:
	for body in _area.get_overlapping_bodies():
		if body is Player and (body as Player).is_on_floor():
			(body as Player).push(Vector2(direction * Player.CONVEYOR_PUSH * 6.0, 0.0))
```

O `* 6.0` compensa o fato de `push()` ser integrada por `delta`; calibrar até
a velocidade de regime bater com os 167 px/s do §1.

4. `levels.gd`, `level_gen.gd`, `codex.gd`, `i18n.gd`.

**Armadilhas**
- **Slime na esteira:** `slime.gd` anda por conta própria lendo a grade, não por
  física. Ele **não** é afetado pela esteira, e isso é bom — deixar assim e não
  desenhar salas que sugiram o contrário. Anotar no comentário do script.
- Empurrão em quem está no ar: não. `is_on_floor()` é a condição, senão a
  esteira vira vento e as duas mecânicas ficam iguais.
- Espelhamento (passo 11) precisa trocar `>` por `<`. Já está previsto lá.
- `verify_rooms.py` precisa somar o empurrão, senão a sala 2 (contramão) é
  declarada impossível.

**Critérios de aceite**
- Parado em cima de `>`, o player é levado a 55 px/s.
- Correndo a favor, chega a ~167 px/s; contra, ~57 px/s.
- Uma faixa de 10 tiles gera 1 nó, não 10.
