# 06 — Inimigo-escudo

**Fase:** 1 · **Tile:** `E` · **Custo:** baixo · **Depende de:** nada

## 1. O que é

Um inimigo terrestre com uma placa no topo: pisar nele mata **você**. Só cai
por queda esmagadora, por ser prensado por plataforma móvel, ou por ser
empurrado contra espinho.

Serve para uma coisa específica: o stomp virou a resposta automática para tudo
que anda no chão. O escudo obriga a olhar antes de pular, e faz a queda
esmagadora (que hoje é usada quase só em bloco `k`) virar ferramenta de combate.

Movimento idêntico ao slime — anda, vira na parede e na beirada — para que a
única diferença a aprender seja a de cima.

## 2. Salas novas no modo história — 4

Entram depois da sala que ensina a queda esmagadora (SLAM, índice 18 hoje).
Antes disso o jogador não tem resposta e o inimigo vira só um obstáculo.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `shield_first` — CASCO | que pisar não resolve | Corredor largo, um `E` sozinho, teto alto o bastante para a queda esmagadora ter curso. Uma gema atrás dele. |
| 2 | `shield_mix` — ESCOLHA | escudo e slime lado a lado | Quatro inimigos alternando `S` e `E` numa fileira; o chain de stomp precisa pular um. |
| 3 | `shield_press` — PRENSA | matar sem pound | Corredor baixo demais para a queda esmagadora, com uma `n` (plataforma vertical) que desce sobre a rota do `E`. |
| 4 | `shield_pit` — EMPURRAO | usar o cenário | Plataforma estreita com `^` embaixo; o `E` vira na beirada, então a solução é bloquear a virada com um bloco `k` quebrado na hora certa. |

```gdscript
## Um escudo, teto alto, e nada mais. A sala é a pergunta "e agora?".
static func _level_shield_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	put(g, 30, 26, "E")
	put(g, 40, 26, "o")
	put(g, 4, 26, "P")
	put(g, 52, 26, "X")
	return bake(g)
```

**Par sugerido:** 26 s, 40 s, 46 s, 52 s.

## 3. Modo infinito

```gdscript
## Um escudo no chão limpo. Custa mais que um slime porque a resposta é uma
## habilidade específica, e no infinito ela está sempre disponível.
static func _shield(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(7, 10), room)
	Levels.put(g, x + w / 2, STAND, "E")
	spots.append(Vector2i(x + w / 2, STAND - 3))
	return w
```

| Tabela | Valor |
| --- | --- |
| `UNLOCK["shield"]` | 10 |
| `THREAT["shield"]` | 4.0 |
| `WIDTHS["shield"]` | 7 |
| `TASTE["shield"]` | 1.6 |

**Impacto:** exige teto. Num segmento sob `canopy` ou dentro de `tower`, a
queda esmagadora não tem curso e o escudo vira intransponível. Guarda
obrigatória no painter: só pintar `E` se as 4 linhas acima de `STAND` estiverem
livres (`_clear_air()` já existe para checagem parecida).

## 4. Codex

```gdscript
{"id": "shield", "kind": CREATURE, "sprite": "shield_a"},
"E": "shield",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `SHIELD` | `THE TOP IS ARMOURED. COME DOWN HARDER, OR NOT AT ALL` |
| PT | `CASCUDO` | `O TOPO E BLINDADO. DESCA COM FORCA, OU NAO DESCA` |
| ES | `ACORAZADO` | `EL TOPE ES BLINDADO. BAJA CON FUERZA, O NO BAJES` |

**Sprites:** `shield_a`/`shield_b` — silhueta do slime com duas linhas de
`Palette.WHITE`/`FRAME` no topo, formando uma placa visível. A leitura tem que
funcionar em 1 frame de pulo, então o contraste do topo é o que importa.

## 5. Para o agente

**Arquivos**
1. `scripts/shield_enemy.gd` — de novo uma cópia de `slime.gd`, com o ramo do
   contato invertido:

```gdscript
	if _approached_from_above and player.is_pounding():
		die()
	else:
		player.kill()
```

`is_pounding()` **já existe** em `player.gd` e devolve true só na fase de
queda (estado 2), não no hang. É exatamente a semântica desejada.

2. `level.gd`
   - caso `"E"` em `_spawn_entities()`, wiring igual ao do slime;
   - injeção de `player` em `_discover_contents()` (ver passo 05, §5);
   - `_on_player_pounded()` **inclui** o escudo no raio de limpeza — ele já
     morre pelo contato direto, mas o raio cobre o caso de o pound cair ao lado.
3. Prensa: `moving_platform.gd` não empurra nem esmaga nada hoje (`collision_mask
   = 0`). Para a sala 3 funcionar, o escudo precisa se matar quando a
   plataforma o sobrepõe. Solução barata, sem física: no `_physics_process()`
   do escudo, checar se algum `MovingPlatform` sobrepõe o retângulo dele e, se
   sim, `die()`. Um `get_tree().get_nodes_in_group("platforms")` resolve; criar
   o grupo em `MovingPlatform._ready()`.

**Armadilhas**
- Ordem do teste: `is_pounding()` **antes** de qualquer coisa. Se o teste de
  aproximação vier primeiro e falhar, um pound ligeiramente torto mata o
  jogador e a mecânica passa a parecer quebrada.
- O escudo não pode ser morto pelo dash. Tentador, mas o dash já é a resposta
  para tudo, e o passo inteiro existe para dar função à queda esmagadora.
- No modo história, salas antes de SLAM não podem conter `E`. Se o passo 00
  (id estável) já estiver feito, verificar por id, não por índice.

**Critérios de aceite**
- Pisar mata o player; queda esmagadora mata o escudo.
- No infinito, nenhum `E` nasce sob teto a menos de 4 tiles.
- Prensa de plataforma vertical mata o escudo.
