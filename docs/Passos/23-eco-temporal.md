# 23 — Eco temporal

**Fase:** 3 · **Tile:** nenhum (habilidade) · **Custo:** alto · **Risco:** de design, não técnico

## 1. O que é

Um botão que devolve o player à posição em que estava há 1 segundo, com a
velocidade daquele instante. Usos limitados por sala (1 ou 2).

A parte técnica é fácil: um ring buffer de 60 posições em `player.gd`, ~30
linhas. **O problema é o resto da sala.**

Quando o player volta 1 segundo, o mundo não volta:

| Coisa | Estado depois do eco |
| --- | --- |
| Gema pega | continua pega |
| Bloco `k` quebrado | continua quebrado |
| Slime morto | continua morto |
| Bloco `c` (crumble) caído | continua caído |
| Bloco `t`/`T` | no ciclo atual, não no de 1 s atrás |
| Interruptor (passo 12) | no estado atual |
| Lava (passo 07) | 1 s mais alta |

Ou seja: o eco cria combinações de posição-do-player × estado-do-mundo que
nenhuma sala foi desenhada para ter. Na maioria dos casos isso é inofensivo ou
até bom (voltar para antes de um erro, com a rota já aberta). Em alguns, é uma
sala impossível — voltar para um ponto de onde a única saída era o bloco que
acabou de cair.

**Decisão recomendada:** implementar como **"volta só o player, o mundo não"**,
com esse contrato escrito no codex em uma frase, e limitar a salas desenhadas
para ele. A alternativa — rebobinar a sala inteira — significa que toda entidade
precisa gravar histórico, e isso é outro projeto.

## 2. Salas novas no modo história — 4

Um mini-capítulo, com o eco disponível **apenas** nele. Fora dessas salas a
habilidade não existe, o que também resolve o problema de reequilibrar as 21
antigas.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `echo_first` — VOLTE | o botão e o alcance | Vão sobre espinhos; pular e ecoar no meio do ar devolve à borda. Um uso, e um chão de socorro se falhar. |
| 2 | `echo_reach` — ALCANCE DOBRADO | eco como distância | Vão de 9 tiles: pular, ecoar no ápice e pular de novo é a única travessia. |
| 3 | `echo_break` — O MUNDO FICA | o contrato explícito | Bloco `k` quebrado com pound; o eco devolve o player para cima do buraco que ele mesmo abriu. |
| 4 | `echo_two` — DOIS USOS | economia do recurso | Três obstáculos, dois ecos: escolher onde gastar. |

```gdscript
## Um vão, um eco. O chão de socorro embaixo existe para a lição não custar vida.
static func _level_echo_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 22, 24, 14, 3, ".")
	rect(g, 22, 27, 14, 1, "-")          # socorro: cair não mata, custa tempo
	put(g, 29, 20, "o")
	put(g, 4, 26, "P")
	put(g, 48, 26, "X")
	return bake(g)
```

**Par sugerido:** 30 s, 42 s, 46 s, 55 s.

## 3. Modo infinito

**Não incluir.** Duas razões independentes, e cada uma bastaria:

1. O gerador não sabe raciocinar sobre uma habilidade que reposiciona o player;
   a prova de alcançabilidade (que é o que mantém o infinito jogável) deixa de
   valer.
2. O eco seria usado principalmente para desfazer erros, o que amortece
   exatamente a tensão que faz uma run de infinito valer alguma coisa.

Se um dia entrar, o formato é o do modificador (passo 20): uma run com eco vale
menos pontos, e a escolha é do jogador.

## 4. Codex

```gdscript
{"id": "echo", "kind": ABILITY, "sprite": "icon_echo"},
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `ECHO` | `YOU GO BACK ONE SECOND. THE ROOM DOES NOT` |
| PT | `ECO` | `VOCE VOLTA UM SEGUNDO. A SALA NAO VOLTA` |
| ES | `ECO` | `VUELVES UN SEGUNDO. LA SALA NO` |

Essa segunda frase é o contrato inteiro da mecânica em quatro palavras. Ela é
obrigatória, e o texto do codex é o único lugar onde ela aparece — o que
significa que a sala 3 do §2 precisa ensiná-la sem depender do texto.

**Visual:** enquanto o buffer grava, um rastro fantasma do player 1 s atrás fica
visível em `Palette.PURPLE` a 25 % de opacidade. Isso resolve dois problemas de
uma vez: o jogador **vê** para onde o eco vai levá-lo antes de apertar, e a
mecânica deixa de ser um salto no escuro.

## 5. Para o agente

**Implementação em `player.gd`:**

```gdscript
const ECHO_FRAMES := 60         # 1 s a 60 Hz de física
const ECHO_USES := 1            # por sala; Level pode sobrescrever

var echo_left := 0
var _echo_pos: PackedVector2Array = PackedVector2Array()
var _echo_vel: PackedVector2Array = PackedVector2Array()
var _echo_head := 0

func _record_echo() -> void:
	_echo_pos[_echo_head] = global_position
	_echo_vel[_echo_head] = velocity
	_echo_head = (_echo_head + 1) % ECHO_FRAMES

func _try_echo() -> void:
	if echo_left <= 0 or not Input.is_action_just_pressed("p_echo"):
		return
	echo_left -= 1
	global_position = _echo_pos[_echo_head]      # o mais antigo é o próximo a escrever
	velocity = _echo_vel[_echo_head]
	_dash = 0.0
	_pound = 0
	refill_dash()
	Audio.play("echo")
```

Os dois arrays são pré-alocados com `resize(ECHO_FRAMES)` no `_ready()` e
preenchidos com a posição de spawn, para que um eco no primeiro meio segundo
devolva ao spawn em vez de a `Vector2.ZERO`.

**Ação de input nova:** `main.gd:_setup_input()` monta o input map à mão.
Adicionar `p_echo` (sugestão: `Shift` / `L` no teclado, gatilho esquerdo no
gamepad) lá, junto com as outras.

**Armadilhas**
- **Ecoar para dentro de terreno.** A posição de 1 s atrás pode estar dentro de
  um bloco que era `t` aberto e agora está fechado, ou de um `g` que o
  interruptor fechou. Testar sobreposição antes de mover e, se houver, gastar o
  uso mesmo assim e matar — ou recusar o eco com um som de erro. **Recomendação:
  recusar** e não gastar; morrer por causa de uma mecânica de correção de erro é
  contraditório.
- Cancelar dash e pound no eco (como no código acima), senão o estado do dash
  continua rodando a partir de uma posição nova e o resultado é imprevisível.
- `Level.restart()` recria o player, então o buffer e os usos zeram sozinhos.
  Conferir que `echo_left` é setado no `_spawn_player()`.
- O rastro fantasma custa um `Sprite2D` a mais e um `queue_redraw()` por frame.
  Irrelevante em 480×270.
- Combo (passo 10): o eco conta como verbo? **Não.** Ele desfaz, não constrói.
- Medalha de tempo (passo 08): o eco economiza tempo, então as 4 salas precisam
  de par calculado **com** o eco em uso.

**Critérios de aceite**
- O eco devolve exatamente à posição de 60 frames de física atrás.
- O rastro fantasma mostra o destino antes do uso.
- Eco para dentro de parede é recusado sem gastar o uso.
- Fora das 4 salas do capítulo, a habilidade não existe.
