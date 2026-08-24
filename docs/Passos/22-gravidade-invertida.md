# 22 — Gravidade invertida

**Fase:** 3 · **Tile:** `V` (zona) · **Custo:** alto · **Risco:** o mais alto da lista

## 1. O que é

Zonas curtas da sala onde a gravidade do player aponta para cima: ele corre no
teto, pula para baixo, e o wall jump e a queda esmagadora invertem junto. Zonas,
nunca a sala inteira — a sala inteira invertida é a mesma sala de cabeça para
baixo, e não ensina nada novo.

**Por que é Fase 3:** todo o resto da lista adiciona coisas ao mundo. Esta muda
o `player.gd`, que é o único arquivo do qual **todas** as 21 salas dependem.
Sete sistemas mudam de sinal:

| Sistema | O que muda |
| --- | --- |
| `up_direction` | `Vector2.UP` → `Vector2.DOWN` na zona |
| `_apply_gravity()` | sinal de `GRAVITY_UP`/`GRAVITY_DOWN` e do teto de `MAX_FALL` |
| `JUMP_VELOCITY` | sinal |
| `_handle_jump()` / `JUMP_CUT` | o teste `velocity.y < 0.0` inverte |
| Wall jump | `WALL_JUMP.y` inverte; `WALL_SLIDE_SPEED` também |
| Queda esmagadora | `POUND_SPEED` inverte, e "landing" passa a ser o teto |
| Sprite | `flip_v`, e o `_squash()` inverte o eixo |

Mais `floor_snap_length`, `previous_bottom` (que os inimigos usam para decidir
stomp) e o `_fx_at()` de todas as partículas.

## 2. Salas novas no modo história — 5

Um capítulo próprio, no fim da campanha, depois de tudo.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `grav_first` — DE CABECA | a zona e a transição | Sala simétrica: chão embaixo, chão em cima, uma faixa `V` no meio da largura. Nada mata. |
| 2 | `grav_gap` — VAO DUPLO | vão que só se cruza pelo teto | Buraco largo no piso, teto contínuo; a zona `V` cobre o buraco. |
| 3 | `grav_spike` — DOIS CHAOS | espinhos nos dois lados | Corredor com `^` embaixo e `v` em cima; a zona obriga a escolher qual superfície usar. |
| 4 | `grav_wall` — PAREDE INVERTIDA | wall jump invertido | Chaminé dentro da zona: o wall jump joga para baixo. |
| 5 | `grav_pound` — MARTELO PARA CIMA | queda esmagadora invertida | Bloco `k` no teto, alcançável só com pound invertido. |

```gdscript
## Chão embaixo, chão em cima, e uma faixa no meio que decide de que lado você
## anda. Nada aqui mata: a sala inteira é uma demonstração.
static func _level_grav_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 0, 1, COLS, 4, "#")
	rect(g, 24, 5, 12, 22, "V")          # a zona, no meio da sala
	puts(g, [Vector2i(30, 6), Vector2i(30, 25)], "o")
	put(g, 4, 26, "P")
	put(g, 50, 26, "X")
	return bake(g)
```

**Par sugerido:** 30 s, 45 s, 55 s, 60 s, 55 s.

## 3. Modo infinito

**Não gerar.** O gerador constrói salas apoiadas numa premissa única: existe um
piso em `FLOOR` e tudo acontece acima dele. Gravidade invertida exige teto
estruturado, e ensinar isso ao `LevelGen` é reescrevê-lo, não estendê-lo.

Se o passo for bem na campanha, o caminho para o infinito é um **modificador**
(passo 20) do tipo "a sala inteira está invertida" — que é barato porque não
muda a geometria, só o sinal da gravidade e a posição de spawn/porta.

## 4. Codex

```gdscript
{"id": "gravity", "kind": WORLD, "sprite": "grav_zone"},
"V": "gravity",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `FLIP ZONE` | `INSIDE IT, DOWN IS UP. EVERYTHING ELSE STILL WORKS` |
| PT | `ZONA INVERTIDA` | `LA DENTRO, BAIXO E CIMA. O RESTO FUNCIONA IGUAL` |
| ES | `ZONA INVERTIDA` | `AHI DENTRO, ABAJO ES ARRIBA. LO DEMAS IGUAL` |

**Visual:** a zona precisa de limite óbvio — uma coluna de partículas subindo
nas duas bordas, fundo levemente diferente (`Palette.BG_SOFT` em xadrez), e o
sprite do player virando de cabeça para baixo com um giro de 0,12 s no
`_squash()`. A transição é o momento mais confuso da mecânica; investir tudo ali.

## 5. Para o agente

**Regra número um: fazer num branch, sozinho, e validar as 21 salas antes de
qualquer coisa.** As 21 salas são o teste de regressão deste passo. Se alguma
mudar de tempo, alguma coisa quebrou.

**Implementação, em `player.gd`:**

```gdscript
var gravity_dir := 1.0          # 1 = normal, -1 = invertido
```

e trocar sistematicamente:

| Antes | Depois |
| --- | --- |
| `up_direction = Vector2.UP` (implícito) | `up_direction = Vector2(0, -gravity_dir)` |
| `velocity.y += g * delta` | `velocity.y += g * gravity_dir * delta` |
| `velocity.y = JUMP_VELOCITY` | `velocity.y = JUMP_VELOCITY * gravity_dir` |
| `if velocity.y < 0.0` | `if velocity.y * gravity_dir < 0.0` |
| `minf(velocity.y, MAX_FALL)` | `if gravity_dir > 0: minf(...) else: maxf(...)` |
| `previous_bottom = pos.y + HEIGHT*0.5` | `+ HEIGHT*0.5*gravity_dir` |

O padrão é sempre o mesmo: **multiplicar por `gravity_dir` antes de comparar**.
Comparações com zero são o que quebra; valores absolutos não.

**A transição.** Entrar na zona não pode inverter no meio de um pulo sem aviso —
o jogador perde o controle. Duas opções:

- **A (recomendada):** a inversão acontece na borda da zona e a velocidade
  vertical é **preservada em módulo e invertida em sinal**, o que faz a
  trajetória continuar visualmente contínua.
- **B:** zerar `velocity.y` na transição. Mais previsível, mais brusco, e
  destrói qualquer momentum. Só se A ficar caótica em playtest.

**Armadilhas**
- **Inimigos.** `slime.gd` e `bat.gd` usam `previous_bottom` e comparações de
  altura para decidir stomp. Um player invertido "pisando" num slime vem de
  baixo. Decisão: inimigos dentro de zona invertida também invertem? A resposta
  barata e coerente é **não colocar inimigos dentro de zonas** na primeira
  versão, e dizer isso na regra de desenho.
- `floor_snap_length = 4.0` gruda o player ao chão; com `up_direction`
  invertido o Godot cuida disso sozinho, mas só se `up_direction` for atualizado
  **antes** do `move_and_slide()`.
- `_squash()` usa `Vector2(x, y)` fixo; invertido, o esmagamento fica ao
  contrário. Multiplicar o eixo y pelo `gravity_dir`.
- Partículas de `fx.gd` recebem direções fixas (`Vector2.UP` em `_land_pound()`,
  por exemplo). Todas precisam do fator.
- `verify_rooms.py` replica a física inteira. Ou ele aprende a inversão, ou as
  5 salas novas ficam fora da validação automática — e para um passo deste
  risco, ficar fora não é aceitável. Orçar o trabalho no checker junto.

**Critérios de aceite**
- As 21 salas antigas: tempos e alcançabilidade idênticos, checker passando.
- Entrar e sair da zona 50 vezes sem travar, prender ou perder controle.
- Wall jump, dash e queda esmagadora corretos dentro da zona.
