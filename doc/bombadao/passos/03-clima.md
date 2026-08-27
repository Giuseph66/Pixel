# BOMBADO — clima pesado

Enquanto o bombado esta em cena a sala inteira precisa parecer que esta
aguentando o peso dele.

O projeto nao tem shader em lugar nenhum — `scripts/darkness.gd` diz isso com
todas as letras e resolve o modificador `dark` com quatro `draw_rect()`. O
clima do bombado segue o mesmo caminho: um `Node2D` que desenha retangulos de
1px.

## `scripts/buff_aura.gd`

Filho do `Level`, adicionado depois do terreno e das entidades, portanto por
cima delas. O `Hud` e irmao do `Level` dentro do `Main` e e adicionado depois,
entao continua por cima da aura — mesma garantia que o `Darkness` ja tem.

Camadas, de baixo para cima:

1. **Escurecimento** — um retangulo de tela cheia em `Palette.OUTLINE` com
   alpha subindo ate `0.30`. E o que faz o bombado "pesar" na sala.
2. **Vinheta** — quatro faixas nas bordas com alpha maior, em dois degraus.
   Degrau duro, sem gradiente, para casar com o pixel.
3. **Brasas** — 44 pixels soltos subindo devagar (12 a 30 px/s), com deriva
   lateral em seno, reaparecendo embaixo ao sair por cima. Cores sorteadas
   entre `CYAN`, `CYAN_MID` e `GOLD`.
4. **Onda de pressao** — a cada 1.6s um quadrado vazado nasce nos pes do
   jogador e cresce ate 70px, sumindo. Sao quatro `draw_rect()` de 1px.
5. **Barras de forca** — duas faixas horizontais finas, uma no topo e uma na
   base da tela, tremendo 1px, em `CYAN_MID` com alpha baixo.

`intensity` vai de 0 a 1: sobe em 0.5s na entrada, cai em 0.4s na saida, e
todo alpha e escala multiplica por ela. Ninguem aparece ou some estalando.

## Tremor

`Level.shake()` ja existe. Durante `BUFF_ON` o `Level` chama `shake(0.8)` a
cada 0.9s — um tremor de fundo, quase subliminar, so para o chao nunca ficar
totalmente parado. Em cima disso:

- nascimento: shake sobe de 2 a 10 ao longo dos 0.85s, com 12 no estalo final;
- pose: 2.0;
- pouso de pisao bombado: 9.0.

## Som

Quatro entradas novas em `Sfx.library()`, geradas como todo o resto:

| chave | som |
|---|---|
| `buff_rise` | rumble grave subindo, onda triangular, 0.9s |
| `buff_ready` | acorde curto e cheio no fim do nascimento |
| `buff_pose` | estalo seco e grave, 0.08s |
| `buff_sink` | rumble descendo, 0.4s |

## Custo

Tudo isso e `draw_rect()` em uma tela de 480x270 e ~50 particulas. E a mesma
ordem de grandeza do `Fx` que ja roda em toda sala.
