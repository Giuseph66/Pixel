# BOMBADO — arte e poses

## Regra do projeto

Nenhum PNG. `scripts/pixel_art.gd` guarda cada sprite como uma lista de
strings, um caractere por pixel, e `from_grid()` transforma em textura no
boot. As grades do bombado entram no mesmo `GRIDS`.

Glifos usados (de `Palette.CHARS`):

| glifo | cor | uso no bombado |
|---|---|---|
| `.` | transparente | fora da silhueta |
| `#` | `OUTLINE` | contorno externo e as pupilas, mais nada |
| `w` | `WHITE` | olhos |
| `c` | claro | borda de cima do musculo (luz) |
| `C` | medio | corpo do musculo |
| `D` | escuro | onde o musculo vira pra baixo |
| `S` | profundo | vinco entre um musculo e o proximo |

`c`/`C`/`D`/`S` **nao** sao lidos da palette: `Player._player_texture()` os
substitui pela cor do jogador (claro / primario / escuro / profundo). Por isso
o bombado sai azul no jogador 1, rosa no jogador 2, etc., de graca.

### O quarto tom

`S` (`Palette.CYAN_DEEP`) existe **so** para estas grades e e a unica excecao a
regra das dezesseis cores. Motivo: com tres tons, o passo de `c` pra `C` e
pequeno demais para separar um peitoral de um deltoide num corpo de 36x44 —
todo vinco sumia e ele lia como um bloco azul. Num sprite de 8x10 tres tons
bastam; neste, nao.

Duas regras seguram o quarto tom:

- `S` vai em face inferior e em vinco curto, **nunca numa linha longa**. Descendo
  o corpo inteiro no tom profundo, uma linha central para de ler como esterno e
  passa a ler como uma listra partindo ele ao meio.
- A linha do abdomen tem **1 pixel**, nao 2. O tronco tem 10 de largura; a
  referencia gasta um vigesimo da largura nesse sulco, e 2px aqui gastariam um
  quinto.

## Formato

Toda grade do bombado tem **36 colunas x 44 linhas**.

- **Cabeca: as primeiras linhas sao a cabeca do proprio personagem**,
  ampliada de `player_idle` — cerca de 12 de largura, centrada, com os
  mesmos dois olhos brancos com pupila. E o que faz a forma continuar sendo
  *ele*: 12 de cabeca contra 36 de ombro, proporcao da referencia.
- Trapezio sai direto do cranio — sem pescoco.
- Deltoides se soltam como bolas proprias; ombro ocupa a largura total.
- **O braco e um membro inteiro**: deltoide, biceps, cotovelo, antebraco,
  punho e nos dos dedos. Ele deixa as costelas e fica com fundo real ate
  o fim. Isso passou por tres versoes: um braco que funde no tronco e some na
  altura do umbigo le como nadadeira, que era exatamente o problema da segunda.
- Punho fecha na altura do quadril, como na referencia.
- **A perna tambem e um membro inteiro**: coxa grossa ate o joelho,
  vinco do joelho, panturrilha voltando a inchar, tornozelo e
  pe como bloco escuro proprio. Perna que afina ate sumir tem o mesmo
  problema que o braco antigo tinha.

O sprite e maior que a colisao (18x32) de proposito: os bracos e o topo da
cabeca passam por fora da caixa. Para o pe cair na linha do chao,
`_sprite_offset_for()` calcula `(HEIGHT - altura_visivel) / 2`, multiplicado por
`gravity_dir`. Essa mesma conta serve para o sprite inteiro e para a fatia que
o nascimento revela, porque `_apply_body_size()` deixa a borda de baixo da
caixa sempre a `HEIGHT * 0.5` do no, seja qual for o tamanho do corpo.

## Lista de grades

Locomocao:

| chave | o que e |
|---|---|
| `buff_idle` | parado de frente, bracos caidos e afastados do corpo |
| `buff_run_a` | contato A, corpo de perfil e perna da frente estendida |
| `buff_run_pass_a` | passagem A, corpo 1px mais alto e pe de tras recolhido |
| `buff_run_b` | contato B, bracos e pernas trocam profundidade |
| `buff_run_pass_b` | passagem B, a outra perna sustenta o corpo |
| `buff_jump` | impulso lateral, perna de apoio estendida e joelho liderando |
| `buff_jump_front` | pulo vertical parado: rosto e tronco de frente, joelhos recolhidos |
| `buff_air` | topo do arco, joelhos recolhidos |
| `buff_fall` | descida lateral, pernas novamente estendidas para o pouso |
| `buff_rise` | pose do nascimento: bracos para cima, **coroa da cabeca no topo** |

Poses (uma para cada quadro da referencia):

| chave | quadro da referencia |
|---|---|
| `buff_pose_double` | dupla de biceps de frente (quadro 2) |
| `buff_pose_lat` | lat spread (quadro 4) |
| `buff_pose_side` | lateral de peito, corpo de lado (quadro 3) |
| `buff_pose_crab` | most muscular, bracos fechando na frente (quadro 8) |
| `buff_pose_back` | dupla de biceps de costas, sem olhos (quadro 6) |
| `buff_pose_point` | apontando pra cima na diagonal (quadro 7) |
| `buff_pose_kneel` | ajoelhado com um braco flexionado (quadro 5) |

`buff_pose_back` e o unico sem `w`: de costas nao se ve olho.

`buff_rise` nao e igual a `buff_pose_double` de proposito. O nascimento e
revelado de cima para baixo, e dois punhos de tres pixels furando o chao
primeiro leem como entulho; com a cabeca no ponto mais alto, a primeira coisa
que sai do chao e inconfundivel.

Duas passagens automaticas terminam cada grade, para nada disso depender de
disciplina na hora de desenhar:

- **`soften`** — todo `#` cercado de corpo nos quatro lados vira `D`. Preto
  quase puro nessa escala fura o musculo em vez de separar; `D` (o tom escuro
  da cor do proprio jogador) separa sem cortar. Pixels encostados num olho
  ficam de fora: a pupila e o unico `#` interno que o desenho quer.
O sombreamento e feito a mao, musculo por musculo, porque nenhuma regra
automatica sabe onde termina um deltoide e comeca um biceps. A luz vem de cima,
sempre: `c` na borda de cima do lobo, `C` no meio, `D` onde ele vira pra baixo,
`S` no vinco contra o proximo.

## Conferencia visual

`tools/render_grids.py` monta um contact sheet PNG das grades a partir do
proprio `pixel_art.gd`, ampliado, para olhar sem abrir o jogo:

```
python3 tools/render_grids.py buff
```

Sai em `/tmp/.../buff_sheet.png`. E ferramenta de conferencia, nao faz parte
do jogo.
