# 13 — Correntes de vento

**Fase:** 2 · **Tile:** `u` · **Custo:** médio · **Depende de:** [00](00-infra-superficie-e-tuning.md) §4.2

## 1. O que é

Uma coluna ou faixa de ar que empurra continuamente quem estiver dentro dela.
Diferente da esteira em duas coisas: age **no ar** (a esteira só no chão) e pode
apontar para cima, sustentando um pulo bem além do alcance normal.

```gdscript
# wind.gd
const PUSH_UP := 620.0          # px/s², contra GRAVITY_DOWN := 1180.0
const PUSH_SIDE := 380.0
```

`PUSH_UP` a ~53 % da gravidade não segura o jogador parado no ar — ele ainda
cai, só que devagar. Isso é deliberado: uma corrente que sustenta indefinidamente
transforma a sala em espera. O que ela dá é **tempo de correção**, que é o que
uma travessia longa precisa.

A direção vem do tile de baixo da coluna, definida na sala pelo desenho: uma
coluna de `u` que sobe do chão empurra para cima; uma faixa horizontal de `u`
empurra na direção do seu comprimento. Se ficar ambíguo, usar caracteres
separados (`u` cima, `U` lado) — decidir na implementação e documentar.

## 2. Salas novas no modo história — 4

Depois das salas de mola (a leitura "algo me lança" já existe).

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `wind_first` — SOPRO | que a coluna sustenta | Vão de 8 tiles com uma coluna de `u` no meio; o pulo normal não cruza, com a coluna cruza. |
| 2 | `wind_climb` — ASCENSAO | subir de coluna em coluna | Três colunas em alturas diferentes; a saída fica no topo da terceira. |
| 3 | `wind_cross` — VENTO CRUZADO | vento lateral contra a rota | Faixa horizontal de `u` empurrando **para trás** sobre uma fileira de plataformas `-`. |
| 4 | `wind_spike` — CORRENTE DE AR | vento com custo | Coluna sobre um poço de `^`: cair dentro é o erro, e o vento perdoa quase o suficiente. |

```gdscript
## O vão é largo demais para um pulo. A coluna cobre a diferença.
static func _level_wind_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 22, 24, 14, 8, ".")           # o vão
	rect(g, 28, 14, 2, 13, "u")           # coluna do fundo até o alto
	put(g, 29, 12, "o")
	put(g, 4, 26, "P")
	put(g, 46, 26, "X")
	return bake(g)
```

**Par sugerido:** 28 s, 42 s, 46 s, 50 s.

## 3. Modo infinito

```gdscript
## Uma coluna sobre um vão. O vento é o único segmento que torna a rota mais
## fácil do que o mapa sugere, e isso é bom: o infinito precisa de respiro.
static func _wind(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var pw := clampi(4 + roundi(d * 3.0), 4, 7)     # vão maior que o normal
	var w := pw + 4
	if w > room:
		return _flat(g, rng, x, room, spots)
	Levels.rect(g, x + 2, FLOOR, pw, 3, ".")
	Levels.rect(g, x + 2, FLOOR + 3, pw, 1, "^")
	Levels.rect(g, x + 2 + pw / 2, FLOOR - 8, 1, 11, "u")
	spots.append(Vector2i(x + 2 + pw / 2, FLOOR - 9))
	return w
```

| Tabela | Valor |
| --- | --- |
| `UNLOCK["wind"]` | 8 |
| `THREAT["wind"]` | 3.0 (o vão é maior que o de `pit`; o vento compensa, não anula) |
| `WIDTHS["wind"]` | 9 |
| `TASTE["wind"]` | 1.8 |

**Impacto:** permite vãos de 7 tiles, acima do limite de 5 que o gerador impõe
hoje ("pits stop at five tiles"). É a primeira exceção àquela regra, então
**precisa** ser a única — o comentário no topo de `level_gen.gd` deve ser
atualizado, senão a próxima pessoa vai achar que a regra caiu.

## 4. Codex

```gdscript
{"id": "wind", "kind": WORLD, "sprite": "wind"},
"u": "wind", "U": "wind",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `UPDRAFT` | `IT SLOWS THE FALL, IT DOES NOT STOP IT. USE THE TIME` |
| PT | `CORRENTE DE AR` | `SEGURA A QUEDA, NAO PARA. APROVEITE O TEMPO` |
| ES | `CORRIENTE` | `FRENA LA CAIDA, NO LA PARA. USA EL TIEMPO` |

**Visual:** o tile é quase invisível — o que comunica é o movimento. Partículas
contínuas sobem pela coluna usando `fx.emit()` (já existe, já é barato) a ~8
partículas/s por tile de coluna, em `Palette.CYAN_DARK`. Sem elas a mecânica é
injusta; com elas, é óbvia à distância.

## 5. Para o agente

**Arquivos**
1. `scripts/wind.gd` — `Area2D` por coluna (não por tile), criada em
   `level.gd` agrupando runs verticais de `u`, do jeito que `_spawn_platforms()`
   agrupa runs horizontais.

```gdscript
func _physics_process(delta: float) -> void:
	for body in _area.get_overlapping_bodies():
		if body is Player:
			(body as Player).push(direction * strength)
	_spawn_particles(delta)
```

2. `player.gd` — nada além do `push()`/`external_force` do passo 00.
3. `level.gd` — agrupamento vertical + repasse do `fx`.
4. `pixel_art.gd`, `codex.gd`, `i18n.gd`, `levels.gd`, `level_gen.gd`.

**Armadilhas**
- **Interação com o dash.** O dash fixa `velocity` todo frame
  (`_tick_dash()`), então `external_force` somada depois é sobrescrita no frame
  seguinte. Resultado: dash dentro do vento ignora o vento, e volta a sentir
  quando acaba. Isso é coerente ("o dash ignora tudo por 0,14 s") — só precisa
  ser deliberado e comentado, não descoberto como bug.
- Mesma coisa com a queda esmagadora, que fixa `velocity = Vector2(0, POUND_SPEED)`.
  Coerente: pound fura vento. Bom para o design.
- Partículas em `fx` são limitadas; uma sala com 4 colunas pode estourar o pool.
  Conferir o teto em `fx.gd` e reduzir a taxa por coluna se necessário.
- Vento que empurra **para dentro** de espinho é injusto se não for visível de
  longe. Regra de desenho: nunca apontar vento para uma morte a menos de 3
  tiles.
- `verify_rooms.py` precisa do vento para não reprovar as salas (o vão de 7
  tiles é intransponível sem ele).

**Critérios de aceite**
- Um pulo dentro da coluna sobe ~2× a altura normal.
- Solto no ar dentro da coluna, o player ainda desce, devagar.
- Uma coluna de 10 tiles gera 1 nó.
