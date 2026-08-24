# 11 — Salas remixadas

**Fase:** 1 · **Tile:** nenhum · **Custo:** médio-baixo · **Depende de:** [00](00-infra-superficie-e-tuning.md) §4.4

## 1. O que é

Depois de terminar a campanha, as mesmas 21 salas ficam disponíveis
espelhadas e mais rápidas. É conteúdo novo pelo preço de uma função pura: a
memória muscular construída em 21 salas deixa de valer, e o jogador tem que
reler o que achava que sabia.

Duas transformações, aplicadas juntas:

1. **Espelho horizontal** — cada linha invertida, `>` vira `<`, `P` e `X`
   trocam de lado por consequência.
2. **Intensidade 1.35** — o campo `intensity` do `data` da sala, que `Level` já
   repassa a slimes, serras, morcegos, plataformas e blocos temporizados. Zero
   código novo: o infinito já usa exatamente esse caminho.

Opcional numa segunda passada: remover as plataformas `-` de socorro, ou
trocar `#` de superfície por `c` (`crumble`). Deixar para depois de sentir o
espelho sozinho — ele pode já ser suficiente.

## 2. Salas novas no modo história — 21 (as mesmas)

Um capítulo novo no seletor, aberto quando `Save.cleared_count() >= 21`. As
salas de remix têm chave de save própria (`"r" + id`), então tempos, gemas e
medalhas do remix são independentes dos da campanha.

**Ordem:** a mesma da campanha. É uma segunda volta, não uma lista embaralhada.

**Habilidades:** todas destravadas desde a primeira sala do remix — o jogador
já terminou o jogo. Isso muda salas iniciais de forma interessante de graça:
FIRST STEPS com dash e queda esmagadora é uma sala diferente.

**Par:** `par * 0.8`. As salas ficam mais rápidas por causa da intensidade e o
jogador ficou melhor; o par antigo seria trivial.

## 3. Modo infinito

Nenhum impacto — o infinito já gera salas novas o tempo todo.

Um uso lateral vale a pena: `mirror()` é útil dentro do `LevelGen` para
espelhar um segmento antes de pintar, dobrando a variedade dos 20 tipos sem
escrever nenhum painter novo. Barato, e pode entrar junto:

```gdscript
# em _paint(), depois de escolher o kind
if rng.randf() < 0.35:
	# pinta num grid temporário e espelha só o trecho
```

Só que espelhar um trecho no meio de um grid maior é mais chato do que parece
(o segmento não sabe sua largura antes de pintar). **Recomendação: não fazer
agora.** Fica anotado como ideia, não como tarefa.

## 4. Codex / apresentação

Sem entrada nova. Precisa de texto:

| Chave | EN | PT | ES |
| --- | --- | --- | --- |
| `remix.title` | `REMIX` | `REMIX` | `REMIX` |
| `remix.locked` | `FINISH THE GAME FIRST` | `TERMINE O JOGO ANTES` | `TERMINA EL JUEGO ANTES` |
| `remix.hint` | `THE SAME ROOMS, MIRRORED AND FASTER` | `AS MESMAS SALAS, ESPELHADAS E MAIS RAPIDAS` | `LAS MISMAS SALAS, EN ESPEJO Y MAS RAPIDAS` |

`play_select_screen.gd` hoje tem dois painéis (história e infinito). Vira três,
com o terceiro trancado até a campanha acabar. O painel de remix mostra quantas
das 21 foram limpas nesse modo.

## 5. Para o agente

**A função, em `levels.gd`:**

```gdscript
## Espelha uma sala no eixo horizontal. Tiles com direção trocam de par; o
## resto é indiferente ao lado.
const MIRROR_PAIRS := {">": "<", "<": ">"}

static func mirror(rows: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for row in rows:
		var line := ""
		for i in range(row.length() - 1, -1, -1):
			var ch := row[i]
			line += String(MIRROR_PAIRS.get(ch, ch))
		out.append(line)
	return out
```

**Onde entra:** `main.gd:_start_room()` ganha um modo:

```gdscript
func _start_room(index: int, remix: bool = false) -> void:
	var data: Dictionary = _levels[index].duplicate()
	if remix:
		data["rows"] = Levels.mirror(data["rows"])
		data["intensity"] = 1.35
		data["par"] = float(data["par"]) * 0.8
	_build_room(index, data)
```

`duplicate()` é obrigatório — sem ele o remix escreve por cima do dicionário
compartilhado e a campanha normal passa a nascer espelhada.

**Armadilhas**
- **A porta `X` marca o tile inferior-esquerdo de um quadro de 2 tiles**
  (`level.gd` desloca `+TILE * 0.5` ao criar). Espelhado, o quadro fica meio
  tile fora de lugar. Duas saídas: compensar o deslocamento quando espelhado,
  ou empurrar a coluna de `X` em 1 depois do espelho. Testar visualmente em
  todas as 21 — é o bug garantido deste passo.
- Tiles assimétricos futuros precisam entrar em `MIRROR_PAIRS`: `>` `<` (passo
  02) e, se existirem, versões direcionais de vento (passo 13) e portal (15).
  Deixar o dicionário num lugar óbvio e comentado.
- Espinho `^`/`v` é vertical: não espelha. Plataformas `m`/`n` medem o alcance
  do grid em runtime, então se ajustam sozinhas.
- Save: usar `"r" + id` como chave, e as medalhas do passo 08 seguem o mesmo
  prefixo automaticamente se `_key()` receber o modo.
- `verify_rooms.py` deve rodar sobre as 21 espelhadas também — é literalmente a
  mesma função aplicada antes da checagem, e pega o problema da porta.

**Critérios de aceite**
- As 21 espelhadas são todas terminaveis (checker passa).
- A porta aparece alinhada ao terreno nas 21.
- Jogar remix não altera nenhum tempo, gema ou medalha da campanha.
- O painel de remix só abre com a campanha terminada.
