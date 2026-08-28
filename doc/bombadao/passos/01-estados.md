# BOMBADO — regras e maquina de estados

## Tecla

`p_buff` — **F** no teclado, **R3** (analogico direito clicado) no controle.

Por que F:

- Nao e usada em nenhum lugar da gameplay. O unico `KEY_F` do projeto esta em
  `scripts/editor_screen.gd:602`, que e a tela do editor, nunca uma sala viva.
- Fica perto de WASD para a mao esquerda e nao briga com `p_dash`
  (SHIFT/C/J) nem com `p_jump` (ESPACO/Z/K).
- R3 e o unico botao de gamepad que ainda esta livre: A=pulo, B=cancelar,
  X/RB=dash, Y=restart, LB=codex+echo, START=pause.

## Liberacao por modo

Uma flag so, propagada pelo mesmo caminho que `dash_unlocked` e
`pound_unlocked` ja usam:

```
main._sandbox  ->  Level.buff_unlocked  ->  Player.buff_unlocked
```

`main.gd::_build_room()` define `_level.buff_unlocked = _sandbox`. Historia,
infinito e remix recebem `false` e a tecla vira letra morta ali.

Sala de sandbox jogada online tambem conta como sandbox (`main._sandbox` ja e
`true` naquele caminho), entao o poder existe la.

## Como entrar

Condicoes, todas ao mesmo tempo, no instante em que `p_buff` e pressionada:

1. `buff_unlocked` e `pound_unlocked` verdadeiros.
2. `_footless` verdadeiro — ou seja, dentro dos 2 segundos depois que um pisao
   pousou. E essa a janela: pular, apertar baixo no ar, pousar achatado, F.
3. `is_on_floor()`.
4. Vivo, nao congelado, controlado localmente.
5. **Espaco livre**: o corpo bombado e 18x32 (contra 6x10 do normal), entao
   precisa de 3 tiles de largura por 4 de altura livres em volta dos pes.
   Sem espaco, o poder e negado com uma poeirinha e um som seco, e o
   `footless` continua correndo normalmente. Melhor negar do que prender o
   jogador dentro da parede.

## Fases

`Player._buff` guarda a fase:

| valor | nome | duracao | o que acontece |
|---|---|---|---|
| 0 | `BUFF_OFF` | — | jogador normal |
| 1 | `BUFF_RISE` | 0.85s | nascendo do chao, sem controle |
| 2 | `BUFF_ON` | ate sair | jogavel, bombado |
| 3 | `BUFF_SINK` | 0.45s | afundando de volta, sem controle |

`BUFF_RISE` e `BUFF_SINK` sao cutscenes curtas: `velocity = Vector2.ZERO`,
input ignorado, colisao ja no tamanho novo (subir com a caixa antiga e depois
crescer empurraria o corpo para dentro do teto).

## Como sair

- `p_buff` de novo, no chao, durante `BUFF_ON`.
- Morte (`kill()`) e respawn: volta ao normal na hora, sem cutscene.
- Fim de sala / `restart()`: idem.

Nao ha timer. Sandbox e bancada de teste; um cronometro so obrigaria o jogador
a repetir o pisao a cada dez segundos.

## O que muda enquanto bombado

Ele e mais forte e mais pesado. Nenhum numero novo e inventado do zero: todos
sao multiplicadores em cima das constantes que ja existem em `player.gd`.

| coisa | normal | bombado | por que |
|---|---|---|---|
| corpo | 6 x 10 | 18 x 32 | e a leitura da forca; custa passagem estreita |
| sprite | 8 x 10 | 36 x 44 | bracos e topo da cabeca passam da caixa de proposito |
| `RUN_SPEED` | 112 | x 0.78 | massa |
| `JUMP_VELOCITY` | -262 | x 0.88 | massa |
| gravidade | 900 / 1180 | x 1.25 | cai como pedra |
| `POUND_SPEED` | 430 | x 1.35 | o pisao e o golpe dele |
| `POUND_REACH` | 13 | 26 | limpa o dobro em volta do pouso |
| `shake` no pouso | 3 | 9 | |
| dash | liga | **desligado** | bombado nao corre, bombado anda |
| `footless` no pouso do pisao | entra | **nao entra** | ele nao perde as pernas |

`WIDTH`/`HEIGHT` continuam constantes; quem le tamanho passa a chamar
`body_width()` / `body_height()`, que respondem pelo estado atual. A caixa
encolhe/cresce **pela cabeca**, igual `_apply_body_height()` ja faz com o
`footless`: a borda de baixo nao sai do lugar, entao pe continua sendo pe para
lava, slime e tudo mais.

## Poses ociosas

Durante `BUFF_ON`, no chao, sem input direcional e com `|velocity.x| < 4`:

- depois de `POSE_WAIT` (0.5s) parado, entra em ciclo;
- sorteia uma pose entre as 7 (nunca a mesma duas vezes seguidas);
- segura por `POSE_HOLD` (1.0s), com um estalo no comeco: `_squash`, poeira,
  `level.shake(2.0)` e o som `buff_pose`;
- volta para `buff_idle` por `POSE_GAP` (0.7s) e sorteia de novo.

Qualquer input quebra o ciclo na hora e volta para `buff_idle`.

## Rede

O snapshot ja carrega o nome da animacao (`Player.network_snapshot()` manda
`anim`). `_player_animation()` passa a aceitar tambem o prefixo `buff_`, entao
o boneco remoto desenha a forma bombada sem protocolo novo.

O corpo remoto e render-only (`_tick_remote`) e por isso **nao** muda de
tamanho de colisao na maquina dos outros — que e exatamente como o `footless`
ja se comporta hoje.
