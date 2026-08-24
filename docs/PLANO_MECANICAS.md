# PIXEL — Plano de mecânicas

**Detalhamento passo a passo, uma mecânica por arquivo:** [docs/Passos/](Passos/README.md)

Auditoria da lista de ideias contra o código atual (`scripts/*.gd`, Godot 4.6),
com o que já está pronto, o que pode ser implementado agora e o que deve
esperar. Escrito em 2026-08-24, commit base `f90e0b2`.

Números de referência (constantes em `scripts/player.gd`): pulo completo sobe
~4,7 tiles e atravessa ~8; mola lança ~14 tiles; dash 232 px/s por 0,14 s.
Sala = grade 60×32 de tiles de 8 px, tela 480×270.

---

## 1. O que já existe

Não vale reimplementar. Referência de arquivo para quem for estender.

| Item da lista | Onde está | Observação |
| --- | --- | --- |
| Dash aéreo, 1 carga | `player.gd` — `DASH_SPEED`, `_try_dash()`, `refill_dash()` | Recarrega em chão, parede, stomp, mola e cristal. Oito direções. |
| Queda esmagadora | `player.gd` — `_try_pound()`, `POUND_*`; `level.gd:_on_player_pounded()` | ↓ + pulo, quebra `k`, limpa slime/bat num raio de 13 px. |
| Super stomp | `player.gd` — `_chain`, `CHAIN_STEP`, `CHAIN_MAX` | Cada inimigo sem tocar o chão dá +9 % de impulso, teto 1,45×. |
| Salto fantasma (recarga aérea) | `dash_crystal.gd`, tile `d` | O "cristal" já é a gema especial que devolve o dash no ar. |
| Plataformas móveis H/V | `moving_platform.gd`, tiles `m` / `n` | Alcance medido do grid em runtime. Falta só a circular. |
| Blocos temporizados | `timed_block.gd`, tiles `t` / `T` | Período 1,15 s, pisca 0,3 s antes de sumir. |
| Blocos quebráveis | `breakable.gd`, tile `k` | Só cai com queda esmagadora. |
| Chão frágil (parte de "modificadores") | `crumble.gd`, tile `c` | Já existe como tile; falta virar modificador global. |
| Serras, espinhos, molas, morcegos, slimes | `saw.gd`, `spike.gd`, `spring.gd`, `bat.gd`, `slime.gd` | — |
| Modo infinito com curva de dificuldade | `level_gen.gd` | Orçamento de ameaça por profundidade + `intensity()` que acelera entidades. |
| Tempo, gemas, mortes por sala | `level.gd`, `save_manager.gd` | Persistidos por slot. Faltam as medalhas em cima disso. |

---

## 2. Trabalho de infraestrutura (pré-requisito de vários itens)

Três peças pequenas destravam metade da lista. Fazer antes das fases.

### 2.1 Consulta de superfície no player

`Player` hoje só conhece `fx`. Gelo, esteira e vento precisam que ele saiba o
que tem sob os pés sem virar dependência de `Level`. Seguir o padrão que
`Slime` já usa (`is_wall`, `is_ground` como `Callable`):

```gdscript
# player.gd
var surface_at: Callable      # func(tx: int, ty: int) -> String, injetada por Level
var external_force := Vector2.ZERO   # zerada a cada frame por quem empurra
```

`_apply_horizontal()` passa a escolher `FRICTION_GROUND` / `ACCEL_GROUND` a
partir do caractere sob os pés, e `move_and_slide()` soma `external_force`.

### 2.2 Variáveis de tuning em vez de constantes cruas

Os modificadores do infinito (velocidade, gravidade) precisam escalar o
movimento. Trocar o uso direto de `RUN_SPEED`/`GRAVITY_*` por multiplicadores:

```gdscript
var speed_scale := 1.0
var gravity_scale := 1.0
```

Constantes ficam como base; nada muda no comportamento padrão (1.0).

### 2.3 Registro de tiles

`level.gd:_spawn_entities()` é um `match` de caracteres e `codex.gd:BY_TILE` é
um mapa paralelo. Cada mecânica nova toca os dois, mais `pixel_art.gd` (sprite)
e `i18n.gd` (nome/descrição em EN/PT/ES). Manter o orçamento de caracteres:

**Em uso:** `. # - ^ v o S J W B c k d t T X P m n`

**Reservados por este plano:** `~` gelo · `>` `<` esteira · `u` vento · `z`
espinho retrátil · `r` plataforma circular · `p` bloco de fase · `i`
interruptor · `g` porta/parede comandada · `L` laser · `e` slime elástico ·
`E` inimigo-escudo · `q` `Q` par de portais · `O` gema secreta

---

## 3. Fase 1 — fazer agora

Itens de custo baixo, risco baixo e que usam sistemas que já existem. Cada um
cabe em um commit.

### 3.1 Gelo (`~`)
Atrito baixo, salas de momentum. Depende de 2.1. Só terreno: pinta como `#`
com paleta clara, colisão idêntica, e o player usa `FRICTION_ICE ≈ 120.0` e
`ACCEL_ICE ≈ 420.0` quando os pés estão sobre ele.
*Arquivos:* `player.gd`, `level.gd`, `pixel_art.gd`, `codex.gd`, `i18n.gd`.

### 3.2 Esteiras (`>` `<`)
Mesma dependência. Somam `CONVEYOR_PUSH ≈ 55.0` px/s ao alvo horizontal
enquanto o player está no chão, o que muda aceleração sem tirar o controle.
Reaproveita `paint_platform()` com um sprite de duas frames para ler a direção.

### 3.3 Espinhos retráteis (`z`)
Já existe espinho e já existe relógio previsível (`timed_block.gd`). Entidade
nova com o ciclo do bloco temporizado e a hitbox do espinho: retraído = área
desligada e sprite rebaixado. Nenhum sistema novo.

### 3.4 Plataforma circular (`r`)
Extensão de `moving_platform.gd`: um terceiro modo que anda em círculo de raio
medido no grid, em vez do vaivém linear. `sync_to_physics` já carrega o player.

### 3.5 Slime elástico (`e`)
Variante de `slime.gd`: o stomp devolve `SPRING_VELOCITY` e **não** mata o
slime, então ele é uma mola que caminha. `player.spring_bounce()` já existe.

### 3.6 Inimigo-escudo (`E`)
Variante de `slime.gd` imune ao stomp (o stomp mata o player). Morre por queda
esmagadora, por prensa de plataforma móvel ou por ser jogado num espinho.
`_on_player_pounded()` já resolve o caso da queda; os outros são de nascença.

### 3.7 Lava subindo (`A` na sala, ou flag no `data`)
Um `Node2D` que sobe a `LAVA_RISE ≈ 9.0` px/s a partir de uma linha inicial e
mata no contato. Estado zerado no `restart()`, como o resto. Encaixa bem no
infinito como sala-marco a cada 5.

### 3.8 Medalhas por sala
`save_manager.gd` já guarda melhor tempo e melhor contagem de gemas; falta
`best_deaths` por sala. Três medalhas independentes: tempo ≤ `par`, todas as
gemas, zero mortes.

```gdscript
# save_manager.gd
func medals(index: int) -> int   # bitmask: 1 tempo, 2 gemas, 4 limpo
```

Desenhar na `results_screen.gd` e na `level_select.gd`. É o item de maior
retorno por linha escrita: dá motivo para repetir 21 salas que já existem.

### 3.9 Gemas secretas (`O`)
Tile próprio, contado fora de `gems_total` para não bloquear a porta (que usa
`charge = taken / total`). Chave nova no save (`secret_gems`) e um marcador no
seletor de salas. Rota difícil é escolha de level design, não código.

### 3.10 Combo de movimento
`player.gd` já conta `_chain` de stomps. Generalizar para um set de verbos
usados sem tocar o chão (dash, wall jump, stomp, mola) e emitir
`combo_changed(count)`. HUD mostra o multiplicador; `level.gd` acumula
pontuação. Reset em `is_on_floor()`, que já é o ponto onde `_chain` zera.

### 3.11 Salas remixadas
Depois da campanha, oferecer as 21 salas espelhadas e com `intensity` maior.
O espelho é uma função pura sobre `PackedStringArray` (inverter cada linha e
trocar `>`/`<`), então não precisa de sala nova nenhuma:

```gdscript
static func mirror(rows: PackedStringArray) -> PackedStringArray
```

Cuidado: espelhar move o spawn `P` e a porta `X`, o que é o ponto, mas invalida
os melhores tempos — guardar em chaves separadas (`"r12"`).

---

## 4. Fase 2 — depois da Fase 1

Custo médio; cada um introduz um sistema novo, mas nenhum mexe na física base.

### 4.1 Interruptores (`i`) + portas comandadas (`g`)
Sem sistema de ligação por ID: o interruptor da sala inverte **todos** os `g`
dela. Uma sala pode ter vários interruptores (todos alternam o mesmo estado) e
`g` nasce sólido ou vazado conforme maiúscula/minúscula, igual a `t`/`T`.
Também desliga serras se a sala tiver `W` — decidir no design da sala, não no
código. Sistema de alvos nomeados só se a Fase 3 pedir.

### 4.2 Correntes de vento (`u`)
`Area2D` que soma a `external_force` (2.1) enquanto o player está dentro.
Sustenta no ar se a força vertical anular parte da gravidade. Precisa de
telegrafia visual forte — partículas contínuas em `fx.gd`, não só um tile.

### 4.3 Bloco de fase (`p`)
Sólido, exceto durante o dash. Colisão desligada enquanto
`player.is_dashing()` (função pública nova, espelhando `is_pounding()`).
Risco: o dash termina dentro do bloco. Mitigação obrigatória — ao fim do dash,
se o player estiver sobrepondo um `p`, empurrar na direção do dash até sair ou
matar. Escolher "empurra" e testar com dash em diagonal.

### 4.4 Portais (`q` / `Q`)
Preservam direção e módulo da velocidade. Precisa de cooldown de reentrada
(~0,15 s) por portal para não criar loop, e de um teste explícito com o player
entrando em dash e em queda esmagadora (que fixa a velocidade a cada frame).

### 4.5 Lasers telegrafados (`L`)
Emissor com ciclo pisca-atira. O feixe é um retângulo até a primeira parede na
direção do emissor, calculado uma vez no spawn (o terreno nunca muda) e testado
por sobreposição durante o disparo. Cuidado com `g` e `t`, que mudam de estado:
nesse caso recalcular o alcance por frame de disparo.

### 4.6 Morcego transportador (`F`)
`bat.gd` hoje morre no stomp. A variante vira `AnimatableBody2D` com
`sync_to_physics`, carrega o player por alguns segundos e depois mergulha.
Médio porque muda o nó base do morcego, e o `_check_player()` manual precisa
virar colisão de verdade no topo com área mortal nas laterais.

### 4.7 Pulo carregado
Parado por ~0,35 s → próximo pulo com `JUMP_VELOCITY * 1.3`. Simples em
`player.gd`, mas **avaliar com cuidado**: recompensar ficar parado vai contra
um jogo cronometrado. Recomendação — só entra se alguma sala for desenhada em
torno dele; caso contrário é uma tecla escondida que ninguém aperta.

### 4.8 Impulso de parede
Wall jump nos primeiros ~5 frames de contato dá `WALL_JUMP.x * 1.25`. Duas
linhas em `_apply_gravity()`/`_handle_jump()` (guardar quando `_wall_dir` mudou
de 0) e um `fx.emit()` diferente para o jogador perceber que acertou.

### 4.9 Modificadores do infinito
Depende de 2.2. Um dicionário aplicado em `_build_room()`:

| Modificador | Como | Custo |
| --- | --- | --- |
| Velocidade | `player.speed_scale = 1.2` | trivial |
| Gravidade | `player.gravity_scale = 1.15` | trivial |
| Chão frágil | `level_gen` troca parte do `#` de superfície por `c` | trivial |
| Escuridão | overlay com um recorte de luz em volta do player | médio |

A escuridão é a única que precisa de trabalho de render — o jogo não usa
shader em lugar nenhum hoje, então fazer com `draw_*` num `CanvasItem` acima do
nível ou aceitar o primeiro shader do projeto. Decidir antes de começar.

### 4.10 Blocos-fantasma (`h`)
Sólidos só com o player parado (ou só em movimento). Barato de escrever,
**caro de comunicar**: o jogador precisa entender a regra sem texto. Só depois
que o resto da Fase 2 estiver jogável.

---

## 5. Fase 3 — não agora

### 5.1 Gravidade invertida
Zonas curtas ainda exigem mexer em `up_direction`, detecção de chão, wall jump,
direção da queda esmagadora, flip do sprite e no `floor_snap_length`. É o item
com mais chance de introduzir bug de física em tudo o que já funciona. Fazer
sozinho, num branch, com as 21 salas existentes como teste de regressão.

### 5.2 Eco temporal
Voltar para a posição de 1 s atrás. O buffer do player é fácil (ring buffer de
60 amostras). O problema é o resto da sala: gemas coletadas, blocos quebrados,
inimigos mortos e ciclos de blocos temporizados não voltam, então o eco cria
estados que nenhuma sala foi desenhada para ter. Se entrar, entra como
"reposiciona só o player, nada mais volta" e com uso limitado — e isso precisa
ser testado como design antes de ser escrito como código.

### 5.3 Clone fantasma que ativa sensores
Gravar e reproduzir entrada, mais um segundo corpo com colisão, mais sensores
que aceitam qualquer um dos dois. É uma mecânica de jogo de puzzle dentro de um
jogo de precisão. Só com uma sala desenhada primeiro no papel.

### 5.4 Fantasma do recorde pessoal
Gravar posições por sala a 20 Hz e guardar no save. Uma corrida de 60 s dá
~1200 amostras; em `saves.json` como pares de inteiros quantizados dá alguns
KB por sala, o que multiplicado por 21 salas × 3 slots cresce rápido. Precisa
de formato binário (`user://ghosts/`) ou de um limite de salas com fantasma.
Decisão de armazenamento antes de qualquer código.

---

## 6. Ordem sugerida

1. Infra 2.1 + 2.2 (uma tarde, destrava seis itens).
2. Medalhas (3.8) e combo (3.10) — dão profundidade sem tile novo.
3. Gelo, esteiras, espinhos retráteis, plataforma circular (3.1–3.4).
4. Slime elástico, inimigo-escudo, lava (3.5–3.7) — variedade de ameaça.
5. Gemas secretas + salas remixadas (3.9, 3.11) — rejogabilidade.
6. Fase 2 na ordem listada; parar e jogar depois de cada item.
7. Fase 3 só com o resto estável.

## 7. Checklist por mecânica nova

Todo tile novo toca a mesma lista. Vale conferir antes de fechar o commit.

- [ ] Caractere reservado na tabela da seção 2.3
- [ ] Sprite em `pixel_art.gd` (grade de caracteres, sem asset importado)
- [ ] Spawn em `level.gd:_spawn_entities()`, e estado zerado por `restart()`
- [ ] Entrada em `codex.gd:ENTRIES` e `codex.gd:BY_TILE`
- [ ] Chaves de nome/descrição em `i18n.gd` nos três idiomas (EN, PT, ES)
- [ ] Som novo em `sfx.gd` se a mecânica tem feedback próprio
- [ ] Pelo menos uma sala em `levels.gd` que ensina a mecânica sem texto
- [ ] Segmento em `level_gen.gd` com custo em `THREAT` e profundidade em `UNLOCK`
- [ ] `tools/verify_rooms.py` passando
