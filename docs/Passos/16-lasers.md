# 16 — Lasers telegrafados

**Fase:** 2 · **Tile:** `L` · **Custo:** médio

## 1. O que é

Um emissor fixo numa parede que dispara um feixe reto até a primeira superfície
sólida. Ciclo previsível de três fases: **dormindo** (nada), **avisando**
(linha fina piscando, 0,5 s), **disparando** (feixe cheio, mata, 0,6 s).

Diferença para o espinho retrátil (passo 03): o laser cobre distância, não um
tile. Ele divide a sala em zonas seguras e inseguras que mudam no tempo, o que
é uma pressão espacial que o jogo hoje só consegue com serras — e serras se
movem devagar e são fáceis de contornar.

```gdscript
# laser.gd
const SLEEP := 1.4
const WARN := 0.5
const FIRE := 0.6               # ciclo total 2,5 s
```

A janela de passagem é de 1,4 s. Com `intensity = 2.2` do infinito ela cai para
~0,64 s, que é o piso do aceitável — travar como no passo 03.

## 2. Salas novas no modo história — 4

Depois das salas de blocos temporizados e espinhos retráteis: é a terceira
lição de ritmo, e a mais exigente.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `laser_first` — FEIXE | o ciclo e o aviso | Corredor com um `L` na parede lateral disparando na horizontal; passagem larga, tempo de sobra. |
| 2 | `laser_stack` — GRADE | dois em fases opostas | Dois `L` em alturas diferentes, alternando; a rota é passar baixo, depois alto. |
| 3 | `laser_climb` — SUBIDA CORTADA | laser no poço de wall jump | Poço com 3 emissores; cada wall jump acontece numa janela. |
| 4 | `laser_gate` — PORTAO | laser + interruptor | O `i` do passo 12 desliga os lasers por 4 s. Só entra se o passo 12 estiver pronto. |

```gdscript
## Um feixe, um corredor, tempo de sobra. A sala ensina a esperar e a ler.
static func _level_laser_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 22, 14, 2, 9, "#")           # pilar que segura o emissor
	put(g, 24, 22, "L")                  # dispara para a direita
	rect(g, 44, 14, 2, 13, "#")          # parede onde o feixe morre
	puts(g, [Vector2i(32, 26), Vector2i(38, 26), Vector2i(50, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)
```

**Par sugerido:** 30 s, 44 s, 52 s, 50 s.

## 3. Modo infinito

```gdscript
## Emissor num pilar, feixe atravessando a rota na altura do peito. O chão
## embaixo continua limpo: agachar não existe neste jogo, então a resposta é
## sempre temporal.
static func _laser(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(10, 13), room)
	Levels.rect(g, x + 1, STAND - 4, 1, 4, "#")
	Levels.put(g, x + 2, STAND - 2, "L")
	Levels.rect(g, x + w - 2, STAND - 4, 1, 4, "#")
	spots.append(Vector2i(x + w / 2, STAND - 5))
	return w
```

| Tabela | Valor |
| --- | --- |
| `UNLOCK["laser"]` | 14 |
| `THREAT["laser"]` | 5.0 (mesmo peso de `saw`) |
| `WIDTHS["laser"]` | 10 |
| `TASTE["laser"]` | 1.8 |

**Impacto:** o infinito ganha ameaça que **para** o jogador em vez de o obrigar
a desviar. Com `retract` (passo 03) e `beat`, forma a família de "threat
temporal", que deve ficar entre 20 % e 30 % do orçamento de uma sala funda —
mais que isso e a corrida vira fila de espera. Como o `_pick()` já penaliza
repetição do mesmo tipo, a regra a acrescentar é uma penalidade cruzada entre
os três tipos temporais.

## 4. Codex

```gdscript
{"id": "laser", "kind": WORLD, "sprite": "laser_idle"},
"L": "laser",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `LASER` | `IT BLINKS, THEN IT FIRES. THE BLINK IS THE INVITATION` |
| PT | `LASER` | `PISCA, DEPOIS DISPARA. O PISCA E O CONVITE` |
| ES | `LASER` | `PARPADEA, LUEGO DISPARA. EL PARPADEO ES LA SENAL` |

**Sprites:** `laser_idle`, `laser_warn`, `laser_fire` para o emissor; o feixe é
`draw_rect()` — 1 px na fase de aviso, 4 px na de disparo, com um núcleo
`WHITE` e borda `CYAN`. Som próprio de carga (sobe de tom) e de disparo em
`sfx.gd`.

## 5. Para o agente

**Arquivos**
1. `scripts/laser.gd` — `Node2D` com `_draw()` e uma `Area2D` retangular
   ligada só na fase de disparo:

```gdscript
## O alcance é medido uma vez no spawn: o terreno é assado e não muda.
func setup(dir: Vector2i, reach_tiles: int) -> void:
```

2. `level.gd`
   - caso `"L"`: descobrir a direção a partir do tile sólido adjacente (o
     emissor aponta para o lado oposto à parede em que está grudado) e medir o
     alcance com `is_solid()` até bater;
   - passar `speed_scale = intensity`.
3. `pixel_art.gd`, `sfx.gd`, `codex.gd`, `i18n.gd`, `levels.gd`, `level_gen.gd`.

**Armadilhas**
- **Terreno que muda.** `g`/`G` (passo 12), `t`/`T` e `k` alteram a solidez
  depois do spawn. Um feixe com alcance medido uma vez atravessa uma porta que
  fechou. Se a sala tiver esses tiles, recalcular o alcance no início de cada
  disparo (é um loop de no máximo 60 iterações, uma vez a cada 2,5 s — irrelevante).
- Direção ambígua: emissor com parede dos dois lados. Definir prioridade fixa
  (direita > esquerda > baixo > cima) e `push_warning()` no caso ambíguo.
- Aviso curto demais mata a mecânica. 0,5 s é o mínimo; não deixar `intensity`
  reduzir a fase de aviso — escalar só `SLEEP`, mantendo `WARN` e `FIRE` fixos.
  Essa é a decisão que mantém o laser justo em profundidade 30.
- O feixe mata durante a fase de disparo inteira, inclusive no primeiro frame.
  Sem "graça" de 2 frames — o aviso já é a graça.
- `verify_rooms.py` ignora tempo: as salas de laser passam trivialmente e a
  validação real é à mão.

**Critérios de aceite**
- Ciclo de 2,5 s estável, com aviso visível de 0,5 s.
- O feixe para na primeira parede, incluindo blocos temporizados fechados.
- Com `intensity = 2.2`, o aviso continua com 0,5 s.
