# 20 — Modificadores do infinito

**Fase:** 2 · **Tile:** nenhum · **Custo:** médio · **Depende de:** [00](00-infra-superficie-e-tuning.md) §4.3

## 1. O que é

Um conjunto de regras que valem para uma run inteira do modo infinito,
escolhidas antes de começar. Hoje toda run é igual e só a profundidade muda; os
modificadores fazem duas runs de 20 salas serem experiências diferentes.

**Quatro para começar:**

| Id | Efeito | Implementação |
| --- | --- | --- |
| `rush` | player 20 % mais rápido | `player.speed_scale = 1.2` |
| `heavy` | gravidade 15 % maior, pulo igual → altura ~13 % menor | `player.gravity_scale = 1.15` |
| `brittle` | parte do chão vira `c` (crumble) | troca no `LevelGen` |
| `dark` | visão limitada a um círculo em volta do player | overlay, ver §5 |

Regras de composição: no máximo **dois** modificadores por run, nunca `rush` +
`heavy` juntos (as duas mexem no movimento e a combinação é ilegível). O jogo
sorteia três combinações válidas e o jogador escolhe uma — escolher é parte do
que torna a run "sua".

**Pontuação:** cada modificador tem um multiplicador (`rush` 1.15, `heavy` 1.2,
`brittle` 1.25, `dark` 1.4) aplicado ao score da run (passo 10). Sem isso, um
modificador difícil é só punição.

## 2. Salas novas no modo história — 0

Nenhuma. Os modificadores são exclusivos do infinito, por escolha: a campanha é
o lugar onde a regra é fixa e o jogador aprende; o infinito é onde ela varia.

Uma exceção defensável no futuro: liberar os modificadores para as salas
remixadas (passo 11), que já são conteúdo pós-campanha. Fica anotado, fora de
escopo aqui.

## 3. Modo infinito — é este o passo

**Fluxo:** `play_select_screen.gd` → painel de infinito → tela nova de escolha
de modificador → `main.gd:_start_run()`.

```gdscript
# main.gd
var _mods: Array[String] = []

func _start_run(mods: Array[String] = []) -> void:
	_mods = mods
	...
```

`_build_room()` aplica:

```gdscript
	_level.player_speed_scale = 1.2 if _mods.has("rush") else 1.0
	_level.player_gravity_scale = 1.15 if _mods.has("heavy") else 1.0
	_level.dark = _mods.has("dark")
```

e `LevelGen.generate()` recebe os mods para o `brittle`:

```gdscript
static func generate(run_seed: int, depth: int, mods: Array = []) -> Dictionary:
	...
	if mods.has("brittle"):
		_make_brittle(g, rng, depth)
```

```gdscript
## Troca parte da superfície por chão que cede. Nunca o apron do spawn nem o da
## saída: a sala tem que continuar começando e terminando em terra firme.
static func _make_brittle(g: Array, rng: RandomNumberGenerator, depth: int) -> void:
	var chance := clampf(0.25 + float(depth) * 0.01, 0.25, 0.5)
	for x in range(START_X, END_X):
		if rng.randf() < chance and String(g[FLOOR][x]) == "#":
			Levels.put(g, x, FLOOR, "c")
```

**Recordes:** guardar o melhor por combinação de modificadores, não só o global.
`endless_best` vira um dicionário com chave `"rush+dark"`. Migração: o valor
antigo entra como chave `""` (sem modificador).

**Impacto na curva:** os modificadores não substituem a progressão de ameaça —
eles multiplicam a run inteira. Uma run `dark` na profundidade 5 já é mais dura
do que uma run limpa na 10, o que é o ponto: dá acesso a dificuldade sem exigir
uma hora de jogo para chegar lá.

## 4. Codex / apresentação

Sem entrada de codex. Texto novo:

| Chave | EN | PT | ES |
| --- | --- | --- | --- |
| `mod.title` | `PICK A TWIST` | `ESCOLHA UMA REGRA` | `ELIGE UNA REGLA` |
| `mod.rush.name` | `RUSH` | `CORRIDA` | `PRISA` |
| `mod.rush.text` | `YOU MOVE FASTER. SO DO YOUR MISTAKES` | `VOCE CORRE MAIS. SEUS ERROS TAMBEM` | `CORRES MAS. TUS ERRORES TAMBIEN` |
| `mod.heavy.name` | `HEAVY` | `PESADO` | `PESADO` |
| `mod.heavy.text` | `GRAVITY WINS. EVERY JUMP IS SHORTER` | `A GRAVIDADE GANHA. TODO PULO ENCURTA` | `LA GRAVEDAD GANA. TODO SALTO ACORTA` |
| `mod.brittle.name` | `BRITTLE` | `QUEBRADICO` | `QUEBRADIZO` |
| `mod.brittle.text` | `THE FLOOR GIVES WAY. DO NOT STAND STILL` | `O CHAO CEDE. NAO FIQUE PARADO` | `EL SUELO CEDE. NO TE PARES` |
| `mod.dark.name` | `DARK` | `ESCURIDAO` | `OSCURIDAD` |
| `mod.dark.text` | `YOU SEE ONLY WHAT IS NEAR` | `VOCE SO VE O QUE ESTA PERTO` | `SOLO VES LO QUE ESTA CERCA` |

A tela de escolha reusa `menu.gd`, que já é o esqueleto de lista de opções do
jogo inteiro.

## 5. Para o agente

**Ordem:** `rush` → `heavy` → `brittle` → `dark`. Os três primeiros são
triviais depois do passo 00 §4.3; o quarto é o único trabalho real.

### A escuridão

O jogo **não usa nenhum shader** hoje — tudo é `draw_rect()` e `Image`. Duas
saídas:

**A. `CanvasItem` com `_draw()`** (recomendada). Um nó acima do nível desenha
quatro retângulos pretos cobrindo tudo menos uma janela quadrada em volta do
player, mais um anel de retângulos menores para arredondar o canto. Nada de
novo no projeto, e o resultado quadrado combina com a estética de pixel.

**B. `CanvasModulate` + luz 2D.** Exige `Light2D`, texturas de luz e mudar o
material de tudo. Bonito e caro. Não vale para o primeiro modificador.

```gdscript
# darkness.gd — opção A
const RADIUS := 46.0

func _draw() -> void:
	var p := _player.global_position - global_position
	var r := RADIUS
	draw_rect(Rect2(0, 0, 480, p.y - r), Palette.OUTLINE)         # cima
	draw_rect(Rect2(0, p.y + r, 480, 270), Palette.OUTLINE)       # baixo
	draw_rect(Rect2(0, p.y - r, p.x - r, r * 2), Palette.OUTLINE) # esquerda
	draw_rect(Rect2(p.x + r, p.y - r, 480, r * 2), Palette.OUTLINE)
```

`queue_redraw()` todo frame no `_process()`. Arredondar `p` para pixel inteiro.

**Armadilhas**
- **Escuridão + gema:** as gemas ficam invisíveis a 5 tiles e a coleta vira
  sorte. Solução: gemas e cristais brilham através da escuridão (desenhar um
  ponto na posição delas por cima do overlay). Sem isso o modificador `dark`
  destrói a coleta em vez de dificultá-la.
- **Escuridão + HUD:** o overlay é filho do `Level`, que fica abaixo do HUD na
  árvore (`main.gd` adiciona os dois). Conferir a ordem; HUD escurecido é bug.
- `brittle` pode transformar o apron de spawn em armadilha. A guarda
  `START_X`/`END_X` no loop já cobre — não remover.
- `heavy` reduz a altura do pulo em ~13 %, o que **quebra** a garantia de
  degraus de 3 tiles do gerador? Não: 4,7 × 0,87 = 4,1 tiles, ainda acima de 3.
  Mas com `heavy` **e** uma sala de vão máximo (5 tiles), a margem cai para
  quase nada. Testar a combinação explicitamente; se falhar, `heavy` reduz o
  vão máximo do gerador para 4.
- Recordes por combinação inflacionam o save. São 4 mods, no máximo 2 por run:
  11 combinações. Aceitável.

**Critérios de aceite**
- Escolher `rush` deixa o player mensuravelmente mais rápido e o resto igual.
- `brittle` nunca transforma o tile de spawn nem o da porta.
- `dark` não escurece o HUD e deixa gemas visíveis.
- Cada combinação guarda seu próprio recorde.
