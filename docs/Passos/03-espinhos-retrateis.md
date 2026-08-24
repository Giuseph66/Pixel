# 03 — Espinhos retráteis

**Fase:** 1 · **Tile:** `z` · **Custo:** baixo · **Depende de:** nada

## 1. O que é

Espinho com relógio. Fica recolhido (inofensivo, rente ao chão) por um tempo,
sobe (mata) por outro, e avisa antes de subir. O ciclo é o mesmo que
`timed_block.gd` já usa, então o jogador que aprendeu a ler `t`/`T` já sabe ler
`z` — a batida é a mesma do jogo inteiro.

O que ele adiciona: **espera com custo**. O espinho fixo é uma parede no
espaço; o retrátil é uma parede no tempo, e num jogo cronometrado esperar dói.

```gdscript
# retract_spike.gd
const PERIOD := 1.15            # igual ao TimedBlock, de propósito
const WARN := 0.3
```

Variante maiúscula não é necessária: use `z` normal e `Z` para a fase invertida
(sobe primeiro), pelo mesmo motivo que existem `t` e `T`. Se o orçamento de
caracteres apertar, `z` sozinho com fase derivada da coluna (`tx % 2`) também
funciona e economiza um caractere — mas fica menos previsível para quem desenha
a sala, então a recomendação é ter os dois.

## 2. Salas novas no modo história — 4

Entram logo depois da sala de blocos temporizados, aproveitando o ritmo já
ensinado.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `retract_first` — PULSO | o ciclo, com rota de fuga | Piso normal com 3 grupos de `z` separados por 6 tiles de piso seguro; dá para esperar em qualquer um. |
| 2 | `retract_run` — CORREDOR | atravessar uma fileira inteira numa janela | 12 tiles seguidos alternando `z` e `Z`; existe uma linha reta que passa se sair na batida certa. |
| 3 | `retract_drop` — QUEDA CERTA | ciclo em cima de plataforma temporizada | `t`/`T` acima, `z` embaixo: o bloco te entrega no chão exatamente quando o espinho está baixo. |
| 4 | `retract_saw` — DUPLA | ciclo somado a serra | Corredor com `W` patrulhando e `z` no piso — as duas janelas precisam coincidir. |

```gdscript
## Três pulsos, com terra firme entre eles. Aqui esperar é sempre uma opção.
static func _level_retract_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	for x in [14, 26, 38]:
		rect(g, x, 26, 3, 1, "z")
	puts(g, [Vector2i(20, 25), Vector2i(32, 25), Vector2i(44, 25)], "o")
	put(g, 4, 26, "P")
	put(g, 52, 26, "X")
	return bake(g)
```

**Par sugerido:** 26 s, 34 s, 40 s, 48 s.

## 3. Modo infinito

```gdscript
## Um pulso no chão. Barato em espaço e caro em tempo, que é justamente o que
## falta nos segmentos existentes: quase todos custam distância.
static func _retract(g: Array, rng: RandomNumberGenerator, x: int, room: int, d: float,
		spots: Array[Vector2i]) -> int:
	var sw := clampi(2 + roundi(d * 2.0), 2, 4)
	var w := sw + 4
	if w > room:
		return mini(4, room)
	var flip := rng.randf() < 0.5
	Levels.rect(g, x + 2, STAND, sw, 1, "Z" if flip else "z")
	spots.append(Vector2i(x + 2 + sw / 2, STAND - 3))
	return w
```

| Tabela | Valor |
| --- | --- |
| `UNLOCK["retract"]` | 7 (logo depois de `beat`, que ensina o mesmo relógio) |
| `THREAT["retract"]` | 2.5 |
| `WIDTHS["retract"]` | 6 |
| `TASTE["retract"]` | 1.5 |

**Impacto:** o infinito hoje é quase todo threat espacial; `retract` e `beat`
são os únicos que cobram tempo. Com os dois na mesa, salas fundas ganham ritmo
em vez de só ficarem mais cheias. Cuidado com o par `retract` + `retract` — o
`_pick()` já penaliza repetição em 0,2×, o que basta.

## 4. Codex

```gdscript
{"id": "retract", "kind": WORLD, "sprite": "spike_up"},
"z": "retract", "Z": "retract",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `TIMED SPIKE` | `RISES AND FALLS ON A BEAT. IT BLINKS BEFORE IT BITES` |
| PT | `ESPINHO PULSANTE` | `SOBE E DESCE NO RITMO. PISCA ANTES DE MORDER` |
| ES | `PUA PULSANTE` | `SUBE Y BAJA A COMPAS. PARPADEA ANTES DE MORDER` |

**Sprites:** `spike_up` (o `spike` existente), `spike_low` (dois pixels de base,
recolhido). Sem sprite intermediário — o piscar já comunica.

## 5. Para o agente

**Arquivos**
1. `scripts/retract_spike.gd` — copiar a estrutura de `timed_block.gd`
   (`_time`, `PERIOD`, `_apply()`), mas em vez de ligar/desligar uma
   `CollisionShape2D` de `StaticBody2D`, ligar/desligar a `Area2D` mortal de
   `spike.gd`.
2. `level.gd:_spawn_entities()` — casos `"z"` e `"Z"`, com
   `speed_scale = intensity` como `TimedBlock` faz.
3. `pixel_art.gd`, `codex.gd`, `i18n.gd`, `levels.gd`, `level_gen.gd`.

**Reaproveitamento:** `spike.gd` tem 36 linhas e já resolve a hitbox e a morte.
A tentação é herdar dele; não vale a pena — `Spike` é `Node2D` com setup por
`setup(down: bool)`. Copiar as ~15 linhas de área e manter os dois
independentes é mais legível do que uma hierarquia de dois níveis para tão
pouco.

**Armadilhas**
- Desligar `monitoring` com `set_deferred()`, nunca direto: mudar estado de
  área dentro do passo de física do Godot dispara erro.
- O relógio começa em `_ready()`. Depois de `level.restart()` todas as
  entidades são recriadas, então o ciclo reinicia junto — o que é o
  comportamento certo, e o jogador conta com isso. Não persistir `_time`.
- `intensity` do infinito acelera o ciclo; abaixo de ~0,7 s de janela a sala
  vira reflexo puro. Travar: `PERIOD / minf(speed_scale, 1.6)`.
- O espinho recolhido **não** é chão: o player passa por cima andando. Não
  registrar colisão sólida nenhuma.

**Critérios de aceite**
- Recolhido, atravessar correndo não mata.
- O piscar começa 0,3 s antes de subir, visível a 60 fps.
- Com `intensity = 2.2`, a janela segura ainda dá ≥ 0,7 s.
