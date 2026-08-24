# 08 — Medalhas por sala

**Fase:** 1 · **Tile:** nenhum · **Custo:** baixo · **Depende de:** [00](00-infra-superficie-e-tuning.md) §4.4 (recomendado)

## 1. O que é

Três selos independentes por sala: **tempo** (terminar dentro do par),
**gemas** (todas as da sala) e **limpo** (zero mortes na tentativa). Cada um é
uma pergunta diferente, e as três raramente se respondem na mesma corrida —
tempo pede rota curta, gemas pedem desvio, limpo pede cautela.

É o item de maior retorno da Fase 1: não adiciona sala nenhuma e dá motivo para
voltar às 21 que já existem. O jogo já mede as três coisas
(`level.gd` guarda `time`, `gems_taken`, `deaths`); só falta guardar e mostrar.

**Regra do selo limpo:** zero mortes **na tentativa que terminou a sala**, não
zero mortes acumuladas. Perder o selo para sempre por uma morte no primeiro dia
transformaria o selo em algo que só existe num save novo.

## 2. Salas novas no modo história — 0

Zero salas novas, mas **as 21 existentes mudam de leitura**. Duas coisas
precisam ser revistas junto:

- **Pares.** Os pares atuais (20 s a 90 s) foram escritos como referência
  amigável, não como alvo de medalha. Rejogar as 21 salas com o par na mão e
  ajustar: o selo de tempo deve cair para quem conhece a rota e falhar para
  quem está aprendendo. Regra prática — par ≈ 1,35× o melhor tempo de um
  jogador que conhece a sala.
- **Gemas alcançáveis.** Conferir que as 3 gemas de cada sala são pegáveis numa
  passada só. `tools/verify_rooms.py` já valida alcançabilidade e serve para
  isso com um alvo diferente.

## 3. Modo infinito

Medalha por sala não faz sentido no infinito (as salas não se repetem). O que
faz sentido, e é barato pelo mesmo código, é uma **linha de recorde de run**:

- profundidade máxima (já existe: `endless_best`);
- salas limpas seguidas (novo: `endless_clean_streak`);
- gemas na run recorde (já existe: `endless_gems`).

Mostrar as três em `ending_screen.gd` e no painel de endless em
`play_select_screen.gd`, que hoje só mostra profundidade.

## 4. Codex / apresentação

Sem entrada de codex — medalha não é coisa do mundo, é do meta. Mas precisa de
texto novo em `i18n.gd`:

| Chave | EN | PT | ES |
| --- | --- | --- | --- |
| `medal.time` | `UNDER PAR` | `NO TEMPO` | `EN TIEMPO` |
| `medal.gems` | `ALL GEMS` | `TODAS AS GEMAS` | `TODAS LAS GEMAS` |
| `medal.clean` | `NO DEATHS` | `SEM MORRER` | `SIN MORIR` |
| `medal.earned` | `MEDAL!` | `MEDALHA!` | `MEDALLA!` |
| `medal.all` | `ROOM MASTERED` | `SALA DOMINADA` | `SALA DOMINADA` |

**Ícones:** três sprites 7×7 em `pixel_art.gd` — `medal_time` (ampulheta),
`medal_gems` (losango), `medal_clean` (coração ou escudo). Apagados quando não
conquistados (`Palette.OUTLINE`), acesos na cor da categoria
(`CYAN` / `GOLD` / `WHITE`).

## 5. Para o agente

### 5.1 Save

```gdscript
# save_manager.gd — blank_slot()
		"medals": {},           # chave de sala -> bitmask
```

```gdscript
const MEDAL_TIME := 1
const MEDAL_GEMS := 2
const MEDAL_CLEAN := 4

func medals(index: int) -> int:
	return int(data["medals"].get(_key(index), 0))

## Chamada de record_clear(). Medalha nunca é perdida, só acumulada.
func _award(index: int, time: float, gems: int, total: int, deaths: int,
		par: float) -> int:
	var earned := 0
	if par > 0.0 and time <= par:
		earned |= MEDAL_TIME
	if total > 0 and gems >= total:
		earned |= MEDAL_GEMS
	if deaths == 0:
		earned |= MEDAL_CLEAN
	var before := medals(index)
	data["medals"][_key(index)] = before | earned
	return earned & ~before          # o que é novidade nesta corrida
```

`record_clear()` hoje recebe `(index, time, gems, level_count)`. Precisa de
`deaths` e `par` — os dois estão disponíveis em `main.gd:_on_room_completed()`
(`_level.deaths` e `_levels[_current]["par"]`). Mudar a assinatura e o único
chamador.

### 5.2 Telas

- `results_screen.gd` — uma linha de três ícones abaixo das estatísticas. Se
  `_award()` devolveu algo, animar só os novos (piscar 3× em `Palette.GOLD`) e
  tocar um som novo em `sfx.gd`.
- `level_select.gd` — três pontinhos por sala na lista; sala com as três vira
  destacada (`medal.all`).
- `title_screen.gd` ou `play_select_screen.gd` — contador global
  `%d/63 MEDALHAS`.

### 5.3 Armadilhas

- **`deaths` no `Level` não zera no `restart()`** — é acumulado desde que a sala
  abriu (`_on_player_died()` faz `deaths += 1`). Isso é o que o selo limpo quer:
  morreu uma vez nessa visita, sem selo. Mas `main.gd:_restart_room()` também
  **não** zera, então voltar pelo menu de pausa mantém a contagem. Decidir e
  documentar: recomendação é zerar em `_restart_room()` (o jogador pediu do
  zero) e manter na morte automática.
- Par 0 (salas de endless) nunca dá medalha de tempo — a guarda `par > 0.0`
  cobre.
- Sala sem gema nenhuma: `total > 0` evita medalha de graça.
- Se o passo 00 §4.4 ainda não foi feito, `_key()` não existe; usar
  `str(index)` e aceitar que inserir sala depois embaralha as medalhas.

### 5.4 Critérios de aceite

- Terminar dentro do par acende o selo de tempo e ele persiste depois de
  fechar o jogo.
- Morrer uma vez e terminar não dá o selo limpo; a medalha já ganhada antes
  continua acesa.
- `level_select.gd` mostra o estado correto para as 21 salas.
