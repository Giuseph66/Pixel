# Passos — uma mecânica por arquivo

Cada arquivo desta pasta descreve **uma** mecânica do
[plano geral](../PLANO_MECANICAS.md), no mesmo formato:

1. **O que é** — a mecânica em si e o que ela muda no jogo.
2. **Salas novas no modo história** — quantas, onde entram, esboço de cada uma.
3. **Modo infinito** — segmento novo, custo de ameaça, profundidade de estreia.
4. **Codex** — a entrada do livro, nos três idiomas.
5. **Para o agente** — arquivos, ordem, armadilhas e critérios de aceite.

Ordem de leitura e de implementação é a numeração dos arquivos.

| # | Mecânica | Fase | Tile | Salas novas |
| --- | --- | --- | --- | --- |
| [00](00-infra-superficie-e-tuning.md) | Infra: superfície e tuning | — | — | 0 |
| [01](01-gelo.md) | Gelo | 1 | `~` | 4 |
| [02](02-esteiras.md) | Esteiras | 1 | `>` `<` | 4 |
| [03](03-espinhos-retrateis.md) | Espinhos retráteis | 1 | `z` `Z` | 4 |
| [04](04-plataforma-circular.md) | Plataforma circular | 1 | `r` | 3 |
| [05](05-slime-elastico.md) | Slime elástico | 1 | `e` | 4 |
| [06](06-inimigo-escudo.md) | Inimigo-escudo | 1 | `E` | 4 |
| [07](07-lava-subindo.md) | Lava subindo | 1 | `A` | 3 |
| [08](08-medalhas.md) | Medalhas por sala | 1 | — | 0 |
| [09](09-gemas-secretas.md) | Gemas secretas | 1 | `O` | 0 (altera 8) |
| [10](10-combo-de-movimento.md) | Combo de movimento | 1 | — | 3 |
| [11](11-salas-remixadas.md) | Salas remixadas | 1 | — | 21 (espelhadas) |
| [12](12-interruptores.md) | Interruptores e portas | 2 | `i` `g` `G` | 5 |
| [13](13-vento.md) | Correntes de vento | 2 | `u` | 4 |
| [14](14-bloco-de-fase.md) | Bloco de fase | 2 | `p` | 5 |
| [15](15-portais.md) | Portais | 2 | `q` `Q` | 5 |
| [16](16-lasers.md) | Lasers telegrafados | 2 | `L` | 4 |
| [17](17-morcego-transportador.md) | Morcego transportador | 2 | `F` | 4 |
| [18](18-pulo-carregado.md) | Pulo carregado | 2 | — | 3 |
| [19](19-impulso-de-parede.md) | Impulso de parede | 2 | — | 3 |
| [20](20-modificadores-infinito.md) | Modificadores do infinito | 2 | — | 0 |
| [21](21-blocos-fantasma.md) | Blocos-fantasma | 2 | `h` `H` | 4 |
| [22](22-gravidade-invertida.md) | Gravidade invertida | 3 | `V` | 5 |
| [23](23-eco-temporal.md) | Eco temporal | 3 | — | 4 |
| [24](24-clone-fantasma.md) | Clone fantasma | 3 | `y` `Y` | 4 |
| [25](25-fantasma-do-recorde.md) | Fantasma do recorde | 3 | — | 0 |

Total se tudo entrar: **21 salas atuais + ~79 novas**, mais 21 remixes.

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

**Em uso hoje:** `. # - ^ v o S J W B c k d t T X P m n`

**Reservados por estes passos:** `~` gelo · `>` `<` esteira · `z` espinho
retrátil · `r` plataforma circular · `e` slime elástico · `E` inimigo-escudo ·
`A` lava · `O` gema secreta · `i` interruptor · `g` `G` porta comandada ·
`u` vento · `p` bloco de fase · `q` `Q` portais · `L` laser · `F` morcego
transportador · `h` `H` bloco-fantasma · `V` zona de gravidade invertida ·
`y` `Y` clone e sensor

### Checklist de fechamento (todo passo com tile novo)

- [ ] Sprite em `pixel_art.gd`
- [ ] Spawn em `level.gd:_spawn_entities()`, estado zerado por `restart()`
- [ ] Entrada em `codex.gd:ENTRIES` e `codex.gd:BY_TILE`
- [ ] Chaves em `i18n.gd` nos três idiomas (EN, PT, ES)
- [ ] Som em `sfx.gd` se a mecânica tem feedback próprio
- [ ] Salas novas em `levels.gd` + entradas em `Levels.all()`
- [ ] Segmento em `level_gen.gd` com `WIDTHS`, `THREAT`, `TASTE`, `UNLOCK`
- [ ] `python3 tools/verify_rooms.py` passando (é lento, ~minutos)
