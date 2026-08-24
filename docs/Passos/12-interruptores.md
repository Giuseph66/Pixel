# 12 — Interruptores e portas comandadas

**Fase:** 2 · **Tiles:** `i` (interruptor), `g` / `G` (porta) · **Custo:** médio

## 1. O que é

Um botão que o jogador atravessa e que inverte o estado de **todas** as portas
da sala. `g` nasce sólida, `G` nasce vazada; o interruptor troca as duas de uma
vez, então uma sala pode abrir um caminho e fechar outro no mesmo toque.

Sem sistema de alvos nomeados, de propósito: uma sala é uma tela, o jogador vê
tudo o que mudou no instante em que muda, e um esquema de IDs custaria parsing
de grade, validação e uma linguagem nova para desenhar sala. Se algum dia uma
sala precisar de dois circuitos independentes, aí sim.

**Estado é da sala, não do interruptor.** Vários `i` na mesma sala alternam o
mesmo booleano — o segundo desfaz o primeiro. É o que torna "voltar no botão"
uma jogada.

O interruptor também pode desligar serras: se a sala tem `W`, ligar o estado
para a patrulha delas é uma linha em `Level`. Usar com parcimônia — uma serra
que para é menos legível do que uma porta que abre.

## 2. Salas novas no modo história — 5

Entram no terço final, depois de o jogador ter dash e queda esmagadora.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `switch_first` — BOTAO | causa e efeito | Corredor bloqueado por `g`; o `i` está 5 tiles antes, à vista da porta. |
| 2 | `switch_trade` — TROCA | que abrir fecha | `g` e `G` em paralelo; a rota certa passa por um e depois pelo outro. |
| 3 | `switch_run` — IDA E VOLTA | o botão como pedágio de tempo | O `i` fica no fim de um desvio; a porta que ele abre fica no começo. |
| 4 | `switch_saw` — DESLIGA | interruptor contra ameaça | Corredor com duas `W`; o `i` congela as duas por 3 s (variante temporizada). |
| 5 | `switch_gems` — CIRCUITO | as 3 gemas em estados diferentes | Duas gemas atrás de `g`, uma atrás de `G`: exige dois toques. |

```gdscript
## Botão à vista da porta que ele abre. A sala inteira é a frase "isso faz aquilo".
static func _level_switch_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 34, 20, 2, 7, "g")           # a parede que fecha o corredor
	put(g, 26, 26, "i")
	puts(g, [Vector2i(20, 25), Vector2i(44, 25), Vector2i(50, 22)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)
```

**Par sugerido:** 30 s, 42 s, 48 s, 46 s, 58 s.

## 3. Modo infinito

```gdscript
## Uma porta no meio do caminho e o botão logo antes dela. No infinito o
## interruptor nunca é um enigma: é um pedágio de meio segundo que quebra o
## ritmo de corrida.
static func _switch(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(10, 13), room)
	Levels.put(g, x + 2, STAND, "i")
	Levels.rect(g, x + w - 4, STAND - 3, 1, 4, "g")
	spots.append(Vector2i(x + w / 2, STAND - 4))
	return w
```

| Tabela | Valor |
| --- | --- |
| `UNLOCK["switch"]` | 12 |
| `THREAT["switch"]` | 2.0 |
| `WIDTHS["switch"]` | 10 |
| `TASTE["switch"]` | 1.4 |

**Impacto:** é o primeiro segmento que **não pode ser atravessado correndo em
linha reta**. Aumenta o tempo de sala sem aumentar a chance de morte, o que
melhora a distribuição do infinito (que hoje só sabe ficar mais mortal).

Guarda obrigatória: nunca gerar `g` sem `i` na mesma sala. O painter garante
isso pintando os dois juntos, mas se alguém adicionar `g` ao `_top_up()`, a
sala vira impossível. Anotar no `_top_up()`.

## 4. Codex

```gdscript
{"id": "switch", "kind": WORLD, "sprite": "switch_off"},
"i": "switch", "g": "switch", "G": "switch",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `SWITCH` | `FLIPS EVERY DOOR IN THE ROOM. OPEN ONE, CLOSE ANOTHER` |
| PT | `INTERRUPTOR` | `INVERTE TODAS AS PORTAS DA SALA. ABRE UMA, FECHA OUTRA` |
| ES | `INTERRUPTOR` | `INVIERTE TODAS LAS PUERTAS. ABRE UNA, CIERRA OTRA` |

**Sprites:** `switch_off`/`switch_on` (alavanca de 8×8, inclinada para os dois
lados) e `gate_solid`/`gate_open` (bloco cheio × moldura vazada). A porta
aberta precisa continuar **visível** como moldura, senão o jogador não entende
que ela pode voltar.

## 5. Para o agente

**Arquivos**
1. `level.gd` — o estado vive aqui:

```gdscript
var switch_state := false
signal switch_toggled(state: bool)

func toggle_switch() -> void:
	switch_state = not switch_state
	switch_toggled.emit(switch_state)
	Audio.play("switch")
	shake(2.0)
```

Zerar em `restart()` — a sala reiniciada precisa voltar ao estado inicial, e
`_spawn_entities()` já é chamado de lá.

2. `scripts/switch_pad.gd` — `Area2D` que chama `toggle_switch()` na entrada do
   player, com trava até o player sair (senão ele alterna 60×/s parado em cima).
3. `scripts/gate_block.gd` — `StaticBody2D` de 1 tile que liga/desliga a
   `CollisionShape2D` conforme `switch_state != inverted`. Conecta-se ao sinal.
4. `pixel_art.gd`, `codex.gd`, `i18n.gd`, `levels.gd`, `level_gen.gd`, `sfx.gd`.

**Armadilhas**
- **Fechar a porta em cima do player.** Se `g` fecha onde o jogador está, ele
  fica preso dentro de um `StaticBody2D` e o `move_and_slide()` o expulsa por
  um lado imprevisível. Decidir a regra e implementá-la: recomendação é **matar**
  (é telegrafado, e prender é pior). Checar sobreposição antes de habilitar a
  forma e chamar `player.kill()`.
- `set_deferred("disabled", ...)` para a colisão, como `TimedBlock` já faz.
- Uma porta de vários tiles é vários nós de 1 tile. Aceitável (as salas terão
  poucas), mas se virar comum, mesclar por coluna como `_spawn_platforms()` faz.
- O `Slime` lê a grade, não a física: ele **atravessa** portas fechadas. Não
  desenhar sala que dependa do contrário, ou fazer `is_wall` consultar
  `switch_state` para os tiles `g`/`G` — a segunda opção é 6 linhas e evita uma
  classe inteira de bug de design.
- Espelhamento (passo 11) não afeta: `i`, `g`, `G` são simétricos.

**Critérios de aceite**
- Um toque alterna todas as portas; dois toques voltam ao início.
- Morrer reinicia o estado.
- Slime não atravessa porta fechada.
