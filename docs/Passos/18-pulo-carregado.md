# 18 — Pulo carregado

**Fase:** 2 · **Tile:** nenhum · **Custo:** baixo · **Ressalva de design: ver §1**

## 1. O que é

Ficar parado no chão por ~0,35 s carrega o próximo pulo: ele sai com
`JUMP_VELOCITY * 1.3`, ou seja ~7,9 tiles de altura em vez de 4,7. O sprite
pisca e uma partícula acumula sob os pés enquanto carrega.

```gdscript
# player.gd
const CHARGE_TIME := 0.35
const CHARGE_BOOST := 1.3
```

**A ressalva:** este jogo é cronometrado e o par de cada sala é a métrica.
Uma mecânica que recompensa **ficar parado** empurra na direção contrária de
tudo o mais. Existem três desfechos possíveis:

1. Ninguém usa, porque parar custa mais tempo do que o pulo alto economiza —
   e aí é código morto num arquivo que é o coração do jogo.
2. Todo mundo usa em todo lugar, e o jogo fica mais lento.
3. Salas específicas o exigem, e ele existe só nelas.

**Recomendação: só implementar junto com as 3 salas do §2**, e só se essas
salas ficarem boas em playtest. Se elas não convencerem, este passo não entra —
e não entrar é um resultado legítimo, não um fracasso.

Alternativa que preserva a ideia sem o custo de tempo: carregar **durante o
wall slide** em vez de parado no chão. O jogador já está imóvel ali, o tempo já
está sendo pago, e o pulo carregado de parede resolve subidas longas. Se for
para escolher uma, é essa.

## 2. Salas novas no modo história — 3

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `charge_first` — PAUSA | que parar carrega | Plataforma de saída a 6 tiles de altura, sem parede, sem mola, sem cristal. Só o pulo carregado alcança. Sem ameaça. |
| 2 | `charge_gap` — FOLEGO | escolher onde parar | Três degraus altos com pouco espaço plano entre eles: dá para carregar em dois deles, não nos três. |
| 3 | `charge_race` — CUSTO | o dilema explícito | Duas rotas: a alta exige duas cargas (0,7 s parado), a baixa é longa. O par premia quem escolher certo. |

```gdscript
## Seis tiles de altura, nenhuma ajuda. A sala é a definição da mecânica.
static func _level_charge_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 34, 21, 14, 6, "#")          # degrau de 6 tiles
	put(g, 40, 20, "o")
	put(g, 4, 26, "P")
	put(g, 44, 20, "X")
	return bake(g)
```

**Par sugerido:** 24 s, 38 s, 42 s.

## 3. Modo infinito

**Nenhum segmento novo.** O gerador garante que todo degrau tem no máximo 3
tiles e todo vão no máximo 5, exatamente para caber no pulo normal. Um degrau
que só o pulo carregado alcança quebraria essa garantia, e a garantia vale mais
do que a variedade.

O que acontece no infinito é indireto e bom: o jogador que aprendeu a carregar
tem uma saída a mais quando erra uma rota e fica preso num nicho baixo. Nada a
implementar.

## 4. Codex

```gdscript
{"id": "charge", "kind": ABILITY, "sprite": "icon_charge"},
```

Descoberto no primeiro pulo carregado (`_found("charge")`, o mesmo mecanismo
que `dash` e `pound` usam).

| Idioma | name | text |
| --- | --- | --- |
| EN | `CHARGED JUMP` | `STAND STILL A MOMENT. THE NEXT JUMP GOES HALF AGAIN` |
| PT | `PULO CARREGADO` | `FIQUE PARADO UM INSTANTE. O PULO SAI BEM MAIOR` |
| ES | `SALTO CARGADO` | `QUEDATE QUIETO UN INSTANTE. EL SALTO SALE MAYOR` |

## 5. Para o agente

**Implementação em `player.gd`, dentro de `_physics_process()`:**

```gdscript
	if is_on_floor() and absf(velocity.x) < 4.0 and absf(input) < 0.01:
		_charge = minf(_charge + delta, CHARGE_TIME)
	elif not is_on_floor():
		pass                     # carga sobrevive ao pulo que ela mesma paga
	else:
		_charge = 0.0
```

e no ramo de pulo de `_handle_jump()`:

```gdscript
		if _coyote > 0.0:
			var boost := CHARGE_BOOST if _charge >= CHARGE_TIME else 1.0
			velocity.y = JUMP_VELOCITY * boost
			_charge = 0.0
```

**Feedback obrigatório.** Sem sinal na tela, a mecânica é invisível e o jogador
nunca descobre. Três coisas, todas baratas com o que já existe:
- `sprite.modulate` pulsa em direção a `Palette.GOLD` conforme `_charge / CHARGE_TIME`;
- `fx.emit()` de 1 partícula subindo a cada ~0,08 s enquanto carrega;
- um `_squash(Vector2(1.15, 0.85))` no instante em que a carga completa, mais um
  som curto em `sfx.gd`.

**Armadilhas**
- O `JUMP_CUT` (0,42) continua valendo: soltar cedo corta o pulo carregado
  também. Isso é certo — a variação de altura é uma regra global do jogo.
- Não deixar a carga sobreviver a uma aterrissagem: `_charge = 0.0` em
  `_on_land()`, senão o jogador acumula carga pulando em sequência e o pulo
  alto vira o padrão.
- Coyote time + carga: pular fora da borda com carga cheia dá o pulo alto. É
  coerente, não corrigir.
- `verify_rooms.py` assume altura de pulo fixa. As 3 salas novas exigem que ele
  aprenda a carga, senão as reprova. Como a carga é opcional em toda sala
  gerada, basta ensinar o checker a considerar as **duas** alturas.
- Se a variante de wall slide (§1) for a escolhida, o gatilho muda para
  `_wall_dir != 0` e o boost vai para `WALL_JUMP`, não para `JUMP_VELOCITY`.

**Critérios de aceite**
- 0,35 s parado dá um pulo de ~7,9 tiles; 0,34 s dá 4,7.
- A carga é visível na tela antes de ser usada.
- Nenhuma sala existente muda de dificuldade (a carga nunca é exigida).
