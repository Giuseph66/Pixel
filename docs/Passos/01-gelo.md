# 01 — Gelo

**Fase:** 1 · **Tile:** `~` · **Custo:** baixo · **Depende de:** [00](00-infra-superficie-e-tuning.md) §4.1

## 1. O que é

Terreno sólido igual ao `#` em colisão, mas com atrito quase nulo. Parar exige
antecipação, virar exige espaço, e a velocidade acumulada vira o recurso da
sala em vez de um detalhe.

O jogo hoje é todo de aceleração alta e freio instantâneo
(`FRICTION_GROUND := 1250.0`, que zera 112 px/s em menos de 0,1 s). O gelo é a
primeira superfície que tira essa garantia, então muda o verbo "correr" sem
adicionar botão nenhum.

**Valores:**

```gdscript
# player.gd
const FRICTION_ICE := 120.0     # ~1/10 do chão normal
const ACCEL_ICE := 420.0        # acelera mais devagar também
```

Com isso, soltar o direcional a 112 px/s desliza ~52 px (6,5 tiles) antes de
parar. Uma plataforma de gelo de 6 tiles é curta, 10 é confortável, 14 é longa.

## 2. Salas novas no modo história — 4

Entram depois da sala de wall jump (a mecânica pede paredes para frear) e
antes das salas de dash.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `ice_first` — PISO LISO | que o chão escorrega, sem nada que mate | Piso inteiro de `~` entre duas ilhas de `#`. Gemas na linha do chão, exigindo parar em cima. Sem espinhos. |
| 2 | `ice_edge` — BEIRADA | que deslizar demais cai | Placas de `~` de 8 tiles separadas por buracos de 4 com `^` no fundo. |
| 3 | `ice_wall` — FREIO | que a parede é o freio | Corredor de gelo terminando em parede alta de `#`; o caminho é bater na parede, escorregar e sair de wall jump. |
| 4 | `ice_slime` — PATINAÇÃO | gelo somado a inimigo que anda | Placa longa de `~` com dois `S` andando em cima e um `-` de fuga no meio. |

Esboço da primeira, no estilo de `levels.gd`:

```gdscript
## Piso liso do começo ao fim. Nada aqui mata; o único inimigo é a inércia.
static func _level_ice_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 10, 27, 40, 1, "~")          # a superfície, só a linha de cima
	puts(g, [Vector2i(18, 26), Vector2i(30, 26), Vector2i(42, 26)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)
```

Note que só a **linha superior** vira `~`: o resto do bloco continua `#`, então
a colisão mesclada por linha em `level.gd:_build_collision()` não muda de forma.

**Par sugerido:** 22 s, 30 s, 34 s, 40 s.

## 3. Modo infinito

Segmento novo `"ice"`: um trecho de piso onde a linha de cima é `~`.

```gdscript
## Uma placa de gelo no meio do caminho. Não mata sozinha — mata em combinação
## com o que vier depois, que é o motivo de ela nunca ser o último segmento.
static func _ice(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(8, 12), room)
	Levels.rect(g, x, FLOOR, w, 1, "~")
	spots.append(Vector2i(x + w / 2, STAND - 3))
	return w
```

| Tabela | Valor | Motivo |
| --- | --- | --- |
| `UNLOCK["ice"]` | 6 | depois de o jogador já ter visto pit, slime e spikes |
| `THREAT["ice"]` | 2.0 | não mata sozinho, mas encurta as margens de tudo |
| `WIDTHS["ice"]` | 8 | menos que isso não dá tempo de sentir |
| `TASTE["ice"]` | 1.6 | — |

**Impacto na curva:** gelo é multiplicador, não somador — uma placa antes de um
`pit` é bem mais dura do que as duas coisas separadas. Regra de segurança no
`_pick()`: proibir `ice` imediatamente antes de `pit`, `spikes` ou `gauntlet` até
`depth >= 12`, com a mesma técnica do `previous` que já está lá.

## 4. Codex

```gdscript
# codex.gd
{"id": "ice", "kind": WORLD, "sprite": "ice"},
# BY_TILE
"~": "ice",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `ICE` | `NO GRIP. STOPPING COSTS GROUND, SO AIM EARLY` |
| PT | `GELO` | `SEM ATRITO. PARAR CUSTA CHAO. MIRE ANTES` |
| ES | `HIELO` | `SIN AGARRE. FRENAR CUESTA SUELO. APUNTA ANTES` |

**Sprite `ice`:** mesma silhueta de `paint_tile()` com a paleta clara —
`Palette.WHITE` no topo, `CYAN_MID` no corpo, e dois pixels de brilho fixos por
tile (fixos, não aleatórios: o terreno é assado uma vez e não pode cintilar).

## 5. Para o agente

**Arquivos, em ordem**
1. `pixel_art.gd` — sprite `ice`, e um ramo em `paint_tile()` ou uma
   `paint_ice()` própria chamada de `level.gd:_bake_terrain()`.
2. `level.gd` — `_bake_terrain()` pinta `~`; `is_solid()` e `is_ground()`
   passam a aceitar `~`; `_build_collision()` idem.
3. `player.gd` — `_apply_horizontal()` escolhe as constantes por `ground_tile()`.
4. `levels.gd` — as 4 salas e as entradas em `all()`.
5. `level_gen.gd` — segmento `_ice()` e as quatro tabelas.
6. `codex.gd`, `i18n.gd`.

**O ponto crítico:** `is_solid()` hoje é `tile_at(...) == "#"`. Três lugares
dependem disso — colisão, `paint_tile()` (bordas) e o `Slime`, que usa
`is_wall`/`is_ground` para virar. Se `~` não entrar em `is_solid()`, os slimes
caem da placa de gelo e a colisão some. Trocar por:

```gdscript
func is_solid(tx: int, ty: int) -> bool:
	var ch := tile_at(tx, ty)
	return ch == "#" or ch == "~"
```

e conferir todo `== "#"` restante no arquivo.

**Armadilhas**
- `tools/verify_rooms.py` replica a física do player em Python. Ele **precisa**
  aprender o gelo, senão vai declarar as salas novas inalcançáveis (ou pior,
  alcançáveis quando não são). Atualizar o atrito lá também.
- Gelo no teto ou na parede não faz sentido; pintar só a linha superior.
- Não dar coeficiente diferente no ar: o gelo é uma propriedade do chão, e
  `FRICTION_AIR` já é baixo.

**Critérios de aceite**
- Correndo a fundo e soltando, o player desliza entre 6 e 7 tiles.
- Slime anda sobre `~` e vira na borda, como em `#`.
- Sala 1 é impossível de perder; sala 4 exige duas correções de rota.
