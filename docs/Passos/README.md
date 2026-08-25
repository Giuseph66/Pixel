# Passos — uma mecânica por arquivo

Cada arquivo desta pasta descreve **uma** mecânica do
[plano geral](../PLANO_MECANICAS.md), no mesmo formato:

1. **O que é** — a mecânica em si e o que ela muda no jogo.
2. **Salas novas no modo história** — quantas, onde entram, esboço de cada uma.
3. **Modo infinito** — segmento novo, custo de ameaça, profundidade de estreia.
4. **Codex** — a entrada do livro, nos três idiomas.
5. **Para o agente** — arquivos, ordem, armadilhas e critérios de aceite.

Ordem de leitura e de implementação é a numeração dos arquivos.

| # | Mecânica | Fase | Tile | Salas novas | Status |
| --- | --- | --- | --- | --- | --- |
| [00](00-infra-superficie-e-tuning.md) | Infra: superfície e tuning | — | — | 0 | ✅ feito |
| [01](01-gelo.md) | Gelo | 1 | `~` | 4 | ✅ feito |
| [02](02-esteiras.md) | Esteiras | 1 | `>` `<` | 4 | ✅ feito |
| [03](03-espinhos-retrateis.md) | Espinhos retráteis | 1 | `z` `Z` | 4 | ✅ feito |
| [04](04-plataforma-circular.md) | Plataforma circular | 1 | `r` | 3 | ✅ feito |
| [05](05-slime-elastico.md) | Slime elástico | 1 | `e` | 4 | ✅ feito |
| [06](06-inimigo-escudo.md) | Inimigo-escudo | 1 | `E` | 4 | ✅ feito |
| [07](07-lava-subindo.md) | Lava subindo | 1 | `A` | 3 | ✅ feito |
| [08](08-medalhas.md) | Medalhas por sala | 1 | — | 0 | ✅ feito |
| [09](09-gemas-secretas.md) | Gemas secretas | 1 | `O` | 0 (altera 8) | ✅ feito |
| [10](10-combo-de-movimento.md) | Combo de movimento | 1 | — | 3 | ✅ feito |
| [11](11-salas-remixadas.md) | Salas remixadas | 1 | — | 0 (reusa as 47) | ✅ feito |
| [12](12-interruptores.md) | Interruptores e portas | 2 | `i` `g` `G` | 5 | ✅ feito |
| [13](13-vento.md) | Correntes de vento | 2 | `u` `U` | 4 | ✅ feito |
| [14](14-bloco-de-fase.md) | Bloco de fase | 2 | `p` | 5 | ✅ feito |
| [15](15-portais.md) | Portais | 2 | `q` `Q` | 5 | ✅ feito |
| [16](16-lasers.md) | Lasers telegrafados | 2 | `L` | 4 | ✅ feito |
| [17](17-morcego-transportador.md) | Morcego transportador | 2 | `F` | 4 | ✅ feito |
| [18](18-pulo-carregado.md) | Pulo carregado | 2 | — | 3 | ✅ feito |
| [19](19-impulso-de-parede.md) | Impulso de parede | 2 | — | 3 | ⬜ não planejado nesta rodada |
| [20](20-modificadores-infinito.md) | Modificadores do infinito | 2 | — | 0 | ⬜ não planejado nesta rodada |
| [21](21-blocos-fantasma.md) | Blocos-fantasma | 2 | `h` `H` | 4 | ⬜ não planejado nesta rodada |
| [22](22-gravidade-invertida.md) | Gravidade invertida | 3 | `V` | 5 | ⬜ não planejado nesta rodada |
| [23](23-eco-temporal.md) | Eco temporal | 3 | — | 4 | ⬜ não planejado nesta rodada |
| [24](24-clone-fantasma.md) | Clone fantasma | 3 | `y` `Y` | 4 | ⬜ não planejado nesta rodada |
| [25](25-fantasma-do-recorde.md) | Fantasma do recorde | 3 | — | 0 | ⬜ não planejado nesta rodada |

Total se tudo entrar: **47 salas atuais + ~26 novas nos passos 10-18**, mais o
remix (reaproveita as 47, não soma).

Nota sobre o passo 11: o plano original previa um quarto painel em
`play_select_screen.gd` (história/infinito/remix). Esse painel já tinha um
terceiro slot — SANDBOX — de um trabalho anterior a este plano. O remix entrou
como um alternador (`R`) dentro da tela de seleção de salas em vez de um quinto
lugar apertado numa tela de 480px de largura.

Notas gerais sobre os passos 12-18, todos implementados nesta rodada:

- **Passo 12** (interruptores): a variante temporizada de "desligar serras"
  descrita como opcional não entrou; `switch_saw` combina botão+porta com uma
  serra no mesmo corredor em vez disso, e o texto da sala foi ajustado para
  não prometer o que não foi construído.
- **Passo 15** (portais): sem segmento no infinito, exatamente como o próprio
  plano recomenda ("não fazer agora, porque quebra a prova de alcançabilidade
  do gerador").
- **Passo 17** (morcego balsa): o alcance do patrulhamento é um valor fixo
  generoso (`SPAN`), não medido contra a sala como `MovingPlatform` faz — mais
  simples, e suficiente para as salas construídas.
- **Passo 18** (pulo carregado): implementada a variante "parado no chão"
  (não a alternativa "carregar no wall slide" que o plano oferece como
  substituta). Sem playtest humano, não dá para confirmar qual das três
  reações previstas pelo plano ("ninguém usa", "todo mundo usa em todo
  lugar", "só onde exigido") descreve o resultado — as 3 salas exigem a
  mecânica, o resto da campanha não.

**Limite honesto, repetido do passo 14 em diante:** nenhuma das salas com
dash, portal, vento ou pulo carregado foi jogada por um humano. `verify_rooms.py`
prova estrutura (existe P, existe X, nada flutua sem chão) — já pegou pelo
menos quatro bugs reais de posicionamento nesta rodada (portas e pontes um
tile fora do lugar). Não prova que uma travessia de dash, um arco de portal ou
um pulo carregado realmente alcança onde deveria. Jogar essas salas e ajustar
números é trabalho que ainda falta.

---

## Regras que valem para todos os passos

### Índice de sala é chave de save — cuidado ao inserir

`save_manager.gd` guarda `best_times`, `cleared` e `gems` por **índice** de
`Levels.all()`, e `DASH_ROOM := 12` / `POUND_ROOM := 18` são índices crus.
Inserir uma sala no meio da campanha embaralha o progresso de todo mundo.

**Antes do primeiro passo que adiciona sala** (ou seja, antes do passo 01),
fazer a migração descrita em [00](00-infra-superficie-e-tuning.md#4-id-estável-de-sala):
cada sala ganha um `"id"` textual estável e o save passa a usar esse id.
Depois disso, inserir sala no meio é livre.

### Sem asset importado

O projeto não tem PNG, WAV nem fonte. Sprite novo é grade de caracteres em
`pixel_art.gd`, som novo é síntese em `sfx.gd`. Nada de `load()` de arquivo.

### Texto sem acento

As strings de `i18n.gd` são desenhadas com a fonte 5×7 de `pixel_font.gd`, que
só tem A–Z, 0–9 e alguns símbolos. Escrever em CAIXA ALTA e **sem acento**,
inclusive em PT e ES ("NAO SE PISA", "GEMAS"). Texto de codex cabe em ~48
caracteres por linha.

### Orçamento de caracteres de tile

**Em uso hoje** (passos 00-18, todos entregues): `. # - ^ v o O S J W B c k d
t T X P m n r e E A z Z ~ > < i g G u U p q Q L K F`

`K` não estava no plano original do passo 16 — saiu de um pedido posterior
para poder montar um laser vertical (`L` só dispara na própria fileira, `K`
só na própria coluna) sem depender do contexto de paredes ao redor escolher
sozinho.

**Ainda reservados, passos 19-25 (não planejados nesta rodada):** `h` `H`
bloco-fantasma · `V` zona de gravidade invertida · `y` `Y` clone e sensor.
Passos 19 (impulso de parede), 20 (modificadores do infinito) e 25 (fantasma
do recorde) não pedem tile novo.

### Checklist de fechamento (todo passo com tile novo)

- [ ] Sprite em `pixel_art.gd`
- [ ] Spawn em `level.gd:_spawn_entities()`, estado zerado por `restart()`
- [ ] Entrada em `codex.gd:ENTRIES` e `codex.gd:BY_TILE`
- [ ] Chaves em `i18n.gd` nos três idiomas (EN, PT, ES)
- [ ] Som em `sfx.gd` se a mecânica tem feedback próprio
- [ ] Salas novas em `levels.gd` + entradas em `Levels.all()`
- [ ] Segmento em `level_gen.gd` com `WIDTHS`, `THREAT`, `TASTE`, `UNLOCK`
- [ ] `python3 tools/verify_rooms.py` passando (é lento, ~minutos)
