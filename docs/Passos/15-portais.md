# 15 — Portais

**Fase:** 2 · **Tiles:** `q` e `Q` (o par) · **Custo:** médio

## 1. O que é

Dois tiles ligados: entrar em um sai no outro **preservando direção e módulo da
velocidade**. Não é teleporte de posição, é continuidade de movimento — cair
num portal no chão e sair de outro no teto mantém a queda, agora vinda de cima.

É a mecânica que mais muda a forma da sala sem mudar nenhuma regra de física.
Uma sala com portal tem topologia diferente: dá para fazer loops, dá para
transformar uma queda longa em velocidade horizontal, dá para pegar impulso
infinito se o design deixar (e não deve).

**Um par por sala.** Vários pares exigem sistema de ligação (o mesmo problema
do passo 12) e confundem a leitura. Se uma sala precisar de dois, é sinal de
que precisa ser duas salas.

## 2. Salas novas no modo história — 5

Perto do fim da campanha. Portal é a mecânica que mais pede vocabulário
anterior.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `portal_first` — PASSAGEM | que sai do outro lado | Sala dividida por uma parede sólida do teto ao chão; o par de portais é a única travessia. Ambos na horizontal, mesma altura. |
| 2 | `portal_fall` — QUEDA LONGA | que a velocidade continua | Portal no fundo de um poço, saída no teto do mesmo poço: cair acelera até dar altura para alcançar a saída. |
| 3 | `portal_turn` — CURVA | direção preservada, orientação nova | Entrada horizontal, saída vertical: a corrida vira subida. |
| 4 | `portal_gem` — VOLTA | o loop como ferramenta | Gema alta que só se alcança entrando no portal com velocidade acumulada em 2 voltas. |
| 5 | `portal_saw` — RISCO | portal sob pressão | Serra patrulhando a boca de entrada; a janela de uso é curta. |

```gdscript
## A parede vai do teto ao chão. Só o par de portais atravessa.
static func _level_portal_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 30, 1, 2, 26, "#")
	put(g, 29, 26, "q")
	put(g, 32, 26, "Q")
	puts(g, [Vector2i(20, 26), Vector2i(40, 26), Vector2i(50, 24)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)
```

**Par sugerido:** 26 s, 40 s, 44 s, 55 s, 50 s.

## 3. Modo infinito

**Recomendação: não gerar portais no infinito na primeira versão.**

O gerador constrói a sala como uma sequência da esquerda para a direita e
garante alcançabilidade por essa leitura linear. Um portal quebra a linearidade:
a prova de que a sala é terminável deixa de valer, e nada no `LevelGen` sabe
raciocinar sobre isso.

Se entrar depois, a forma segura é um portal **redundante** — os dois lados na
mesma rota, a poucos tiles um do outro, servindo de atalho e nunca de ponte:

```gdscript
## Atalho, nunca ponte: a rota de chão entre as duas bocas continua existindo.
static func _portal(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(11, 14), room)
	Levels.put(g, x + 2, STAND, "q")
	Levels.put(g, x + w - 3, STAND - 4, "Q")
	spots.append(Vector2i(x + w / 2, STAND - 3))
	return w
```

| Tabela | Valor (se e quando entrar) |
| --- | --- |
| `UNLOCK["portal"]` | 15 |
| `THREAT["portal"]` | 1.0 |
| `WIDTHS["portal"]` | 11 |
| `TASTE["portal"]` | 1.2 |

## 4. Codex

```gdscript
{"id": "portal", "kind": WORLD, "sprite": "portal_a"},
"q": "portal", "Q": "portal",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `PORTAL` | `SPEED AND HEADING SURVIVE THE TRIP. ONE PAIR PER ROOM` |
| PT | `PORTAL` | `VELOCIDADE E DIRECAO SOBREVIVEM. UM PAR POR SALA` |
| ES | `PORTAL` | `VELOCIDAD Y RUMBO SOBREVIVEN. UN PAR POR SALA` |

**Sprites:** `portal_a` e `portal_b` — mesma forma, cores trocadas
(`CYAN` × `PURPLE`), com 2 frames de rotação interna. As cores diferentes são o
que ensina o par sem texto.

## 5. Para o agente

**Arquivos**
1. `scripts/portal.gd`:

```gdscript
const COOLDOWN := 0.18          # por portal, para não reentrar em loop

var twin: Portal
var _cool := 0.0

func _physics_process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	if _cool > 0.0 or twin == null:
		return
	for body in _area.get_overlapping_bodies():
		if not (body is Player):
			continue
		var p := body as Player
		p.global_position = twin.global_position + p.velocity.normalized() * 8.0
		twin._cool = COOLDOWN        # o destino também trava
		_cool = COOLDOWN
		Audio.play("portal")
```

2. `level.gd` — casa os dois na `_spawn_entities()`, depois de varrer a grade
   (o segundo portal ainda não existe quando o primeiro é criado):

```gdscript
	if _portal_a != null and _portal_b != null:
		_portal_a.twin = _portal_b
		_portal_b.twin = _portal_a
```

3. `pixel_art.gd`, `codex.gd`, `i18n.gd`, `levels.gd`, `sfx.gd`.

**Armadilhas**
- **O cooldown é do destino, não da origem.** Travar só a origem faz o player
  sair do destino e ser imediatamente reabsorvido. Travar os dois, como no
  código acima.
- O deslocamento de 8 px na saída (`velocity.normalized() * 8.0`) evita nascer
  dentro do próprio portal. Com velocidade zero (player parado empurrado por
  esteira, por exemplo), `normalized()` dá zero — cair para
  `Vector2(p.facing, 0)`.
- **Queda esmagadora atravessando portal:** `_tick_pound()` fixa
  `velocity = Vector2(0, POUND_SPEED)` todo frame. Sair de um portal lateral em
  pound produz um pound horizontal, que não existe. Cancelar o pound na
  travessia (`p.cancel_pound()`, função nova de 3 linhas) é mais simples do que
  suportar o caso.
- Dash atravessando: `_dash_dir` continua o mesmo, então o dash sai na direção
  antiga mesmo que o portal aponte para outro lado. Se a saída for vertical,
  isso fica errado. Rotacionar `_dash_dir` junto, ou cancelar o dash como no
  pound. **Recomendação: rotacionar** — o dash através de portal é a jogada
  boa da mecânica.
- Sala com `q` sem `Q` (erro de desenho) tem que falhar alto: `push_error()` no
  `_spawn_entities()`, não silenciosamente virar um portal morto.
- Espelhamento (passo 11): `q`/`Q` não trocam entre si — só as posições
  invertem, e o par continua o par.

**Critérios de aceite**
- Entrar correndo a 112 px/s sai a 112 px/s.
- Nenhum loop de reentrada em 30 travessias seguidas.
- Sala 2 (queda longa) é terminável e a velocidade acumulada é visível.
