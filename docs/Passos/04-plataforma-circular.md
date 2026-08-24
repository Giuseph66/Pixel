# 04 — Plataforma circular

**Fase:** 1 · **Tile:** `r` · **Custo:** baixo · **Depende de:** nada

## 1. O que é

Terceiro modo de `moving_platform.gd`. As atuais fazem vaivém em linha (`m`
horizontal, `n` vertical); esta percorre um círculo. A diferença de jogo é que
o embarque e o desembarque acontecem em pontos diferentes do trajeto, então a
sala tem uma janela de fase em vez de duas pontas.

```gdscript
# moving_platform.gd
const ORBIT_SPEED := 1.1        # rad/s, ~5,7 s por volta
```

Raio: medido do grid como o alcance linear já é medido hoje — anda para fora em
cada direção até bater em algo, com teto de `MAX_TRAVEL := 7`, e usa o menor dos
quatro alcances. Uma plataforma circular sem espaço vira estática (o `setup()`
já desliga o `_physics_process` nesse caso).

## 2. Salas novas no modo história — 3

Entram junto do bloco de plataformas móveis, como terceira lição da mesma
família.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `orbit_first` — ROTA CIRCULAR | que ela volta | Vão largo com uma `r` no meio girando num círculo de 4 tiles; embarque na esquerda, desembarque na direita. Sem espinho no vão. |
| 2 | `orbit_gems` — RELOGIO | fase, não velocidade | Duas `r` em contrafase e 3 gemas posicionadas em pontos do círculo; pegar todas exige uma volta a mais. |
| 3 | `orbit_saw` — MOINHO | círculo com ameaça | Uma `r` orbitando ao lado de uma `W` fixa em plataforma: o ponto alto da órbita é o único momento seguro. |

```gdscript
## O vão só se cruza de carona. A órbita passa pelas duas bordas.
static func _level_orbit_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 20, 27, 20, 5, ".")          # o vão, sem espinho: a lição é o embarque
	rect(g, 28, 22, 2, 1, "r")           # slab de 2 tiles, círculo medido do grid
	put(g, 30, 18, "o")
	put(g, 4, 26, "P")
	put(g, 50, 26, "X")
	return bake(g)
```

**Par sugerido:** 30 s, 44 s, 50 s.

## 3. Modo infinito

Reaproveitar o segmento `ferry` (que hoje pinta `m`/`n`) com um terceiro sorteio
em vez de criar segmento novo — o infinito já tem 20 tipos e mais um do mesmo
grupo dilui os outros:

```gdscript
# dentro de _ferry(), onde hoje escolhe entre "m" e "n"
var roll := rng.randf()
var ch := "m" if roll < 0.45 else ("n" if roll < 0.8 else "r")
```

com uma guarda: `r` só a partir de `depth >= 9`, e só se houver 5 tiles livres
em volta (senão vira estática e o segmento fica sem sentido).

| Ajuste | Valor |
| --- | --- |
| `UNLOCK["ferry"]` | continua 4 |
| `THREAT["ferry"]` | 2.0 → 2.4 quando sorteia `r` (somar 0,4 no retorno) |
| `WIDTHS["ferry"]` | 11 → 13 se `r` |

**Impacto:** aumenta o tempo médio de sala no infinito, porque órbita é mais
lenta que vaivém. Como o `par` do infinito é derivado da ameaça
(`12.0 + threat * 1.4 + depth * 0.4`), o +0,4 de ameaça já compensa o par.

## 4. Codex

Não precisa de entrada nova — `platform` já cobre a família e `BY_TILE` só
ganha `"r": "platform"`. Se quiser distinguir, o texto atual
(`SLABS THAT CARRY YOU. RIDE THEM`) continua verdadeiro para as três.

**Decisão:** não criar entrada. Um livro de 20 páginas em que três delas dizem
quase a mesma coisa é pior do que uma página certa.

## 5. Para o agente

**Arquivos:** `moving_platform.gd`, `level.gd` (`_spawn_platforms()` aceita
`"r"`), `levels.gd`, `level_gen.gd`, `codex.gd` (só `BY_TILE`).

**Implementação em `moving_platform.gd`:**

```gdscript
enum Mode { LINEAR_H, LINEAR_V, ORBIT }
var mode := Mode.LINEAR_H
var _radius := 0.0
var _angle := 0.0

# em _physics_process, ramo ORBIT:
	_angle += ORBIT_SPEED * speed_scale * delta
	position = _origin + Vector2(cos(_angle), sin(_angle)).round() * _radius
```

**Armadilhas**
- **Pixels inteiros.** O resto do jogo arredonda tudo (`bat.gd` usa `roundf()`
  no bob, o comentário de `moving_platform.gd` explica o porquê). Uma órbita em
  ponto flutuante cintila contra o terreno. Arredondar a **posição final**, não
  o vetor unitário — `Vector2(cos, sin).round()` colapsa para 8 direções e a
  órbita vira um octógono travado. Usar:
  `position = (_origin + Vector2(cos(_angle), sin(_angle)) * _radius).round()`.
- `sync_to_physics = true` carrega o player de graça, mas só se o movimento for
  feito em `_physics_process()`. Não usar `Tween` para a órbita.
- Em `setup()`, `_radius` sai do **menor** dos quatro alcances medidos; se der
  0, cair no `set_physics_process(false)` que já existe.
- O ângulo inicial deve depender da coluna (`_angle = tx * 0.7`) para que duas
  plataformas iguais na mesma sala não nasçam em fase.

**Critérios de aceite**
- Uma volta completa em ~5,7 s com `speed_scale = 1.0`.
- Player parado em cima é carregado a volta inteira sem escorregar.
- Nenhum shimmer contra o terreno: gravar 5 s e conferir quadro a quadro.
