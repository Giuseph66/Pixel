# 17 — Morcego transportador

**Fase:** 2 · **Tile:** `F` · **Custo:** médio-alto

## 1. O que é

Um morcego que não morre pisado: o jogador **fica em cima dele** e é carregado
enquanto ele completa o trajeto, e depois de alguns segundos ele mergulha e sai
de cena. É uma plataforma móvel viva, com prazo.

O morcego atual (`bat.gd`) morre no stomp e serve de trampolim de um frame. O
transportador é o oposto: chegar em cima não é o fim da interação, é o começo.
E como ele tem prazo, a carona é uma decisão de tempo — ficar mais é ir mais
longe e arriscar o mergulho.

```gdscript
# ferry_bat.gd
const CARRY_TIME := 3.2         # segundos de carona antes do mergulho
const WARN_TIME := 0.8          # ele treme antes de largar
const DIVE_SPEED := 210.0
```

**As laterais e a base continuam mortais.** Só o topo é embarque. Sem isso ele
vira plataforma e perde a identidade.

## 2. Salas novas no modo história — 4

Depois das salas de morcego comum e de plataforma móvel — ele é a fusão das
duas e não faz sentido antes.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `ferry_first` — CARONA | embarque e prazo | Vão intransponível de 12 tiles; um `F` cruza de um lado ao outro. Nada mais na sala. |
| 2 | `ferry_hop` — BALDEACAO | trocar de morcego | Dois `F` em trajetos que se cruzam; a rota exige pular de um para o outro. |
| 3 | `ferry_dive` — MERGULHO | o prazo importa | Vão longo demais para uma carona só; o mergulho tem que ser previsto. |
| 4 | `ferry_spike` — SOBRE OS ESPINHOS | carona com custo do erro | O vão embaixo é todo `^`. |

```gdscript
## Um vão que nenhum pulo cruza e um morcego que cruza. Nada mais.
static func _level_ferry_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 18, 24, 24, 8, ".")
	put(g, 30, 20, "F")
	put(g, 30, 16, "o")
	put(g, 4, 26, "P")
	put(g, 48, 26, "X")
	return bake(g)
```

**Par sugerido:** 32 s, 48 s, 52 s, 56 s.

## 3. Modo infinito

O segmento `ferry` já existe (é o de plataforma móvel). Este entra como
`ferrybat`, separado, porque o comportamento e o risco são outros:

```gdscript
## Um vão largo e um morcego que o cruza. É a única forma de o gerador abrir um
## vão de 8 tiles sem quebrar a regra de alcançabilidade — o transporte é
## garantido, o timing é problema do jogador.
static func _ferrybat(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var pw := 8
	var w := pw + 4
	if w > room:
		return _flat(g, rng, x, room, spots)
	Levels.rect(g, x + 2, FLOOR, pw, 3, ".")
	Levels.rect(g, x + 2, FLOOR + 3, pw, 1, "^")
	Levels.put(g, x + 2 + pw / 2, FLOOR - 4, "F")
	spots.append(Vector2i(x + 2 + pw / 2, FLOOR - 7))
	return w
```

| Tabela | Valor |
| --- | --- |
| `UNLOCK["ferrybat"]` | 13 |
| `THREAT["ferrybat"]` | 4.5 |
| `WIDTHS["ferrybat"]` | 12 |
| `TASTE["ferrybat"]` | 1.7 |

**Impacto:** segunda exceção à regra de vãos de 5 tiles (a primeira é o vento,
passo 13). Duas exceções ainda são administráveis; uma terceira significa que a
regra precisa ser reescrita em vez de remendada.

## 4. Codex

```gdscript
{"id": "ferrybat", "kind": CREATURE, "sprite": "ferry_a"},
"F": "ferrybat",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `FERRY BAT` | `RIDE THE TOP. IT DIVES WHEN IT IS DONE WITH YOU` |
| PT | `MORCEGO BALSA` | `SUBA NO TOPO. ELE MERGULHA QUANDO CANSA` |
| ES | `MURCIELAGO BALSA` | `SUBE ENCIMA. SE ZAMBULLE CUANDO SE CANSA` |

**Sprites:** `ferry_a`/`ferry_b` — o morcego com uma plataforma clara nas costas
(`Palette.GOLD`), o que resolve a leitura "dá para subir". Durante o aviso, ele
pisca; no mergulho, vira `ferry_dive` com as asas fechadas.

## 5. Para o agente

Este é o passo mais delicado da Fase 2, porque muda o **tipo de nó**.

**Arquivos**
1. `scripts/ferry_bat.gd` — `AnimatableBody2D` com `sync_to_physics = true`
   (como `MovingPlatform`), `collision_layer = 2`, mais duas `Area2D` mortais
   nas laterais e embaixo. O movimento continua a senóide de `bat.gd`.

```gdscript
func _physics_process(delta: float) -> void:
	_time += delta
	match _state:
		State.PATROL:
			_move_patrol(delta)
			if _carrying:
				_carry = maxf(_carry - delta, 0.0)
				if _carry <= 0.0:
					_state = State.DIVE
		State.DIVE:
			position.y += DIVE_SPEED * delta
			if position.y > _limit:
				queue_free()
```

2. `level.gd` — caso `"F"`; incluir no raio da queda esmagadora? **Não.**
   Destruir a balsa com pound seria destruir a própria rota.
3. `pixel_art.gd`, `codex.gd`, `i18n.gd`, `levels.gd`, `level_gen.gd`.

**Armadilhas**
- **Detectar que o player está em cima.** `bat.gd` faz colisão à mão porque uma
  `Area2D` reporta tarde demais (ler o comentário no topo de `slime.gd`). Aqui é
  diferente: o topo é colisão de verdade (`AnimatableBody2D`), então o teste é
  `player.is_on_floor() and player.get_last_slide_collision()` apontando para o
  morcego. Simples e exato.
- **Áreas laterais mortais precisam não pegar quem está em cima.** Deixar 3 px de
  folga vertical entre o topo sólido e as áreas mortais; sem isso, aterrissar
  mata em uma de cada cinco tentativas e vira o bug mais reportado do jogo.
- O morcego carrega o player de graça (`sync_to_physics`), mas só se o
  movimento acontecer em `_physics_process()`. A senóide de `bat.gd` já está lá.
- Pixels inteiros: `roundf()` no bob, como `bat.gd` já faz.
- No mergulho, o player em cima **não** deve ser levado junto: o morcego
  desaparece de baixo dele e o pulo é por conta do jogador. Isso é o que dá
  sentido ao aviso de 0,8 s.
- `restart()` recria tudo, então o prazo reinicia. Correto.

**Critérios de aceite**
- Pousar em cima carrega o player sem escorregar.
- Encostar de lado ou por baixo mata.
- O mergulho começa 0,8 s depois do aviso e o morcego some da tela.
- Queda esmagadora não o destrói.
