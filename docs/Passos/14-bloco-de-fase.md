# 14 — Bloco de fase

**Fase:** 2 · **Tile:** `p` · **Custo:** médio

## 1. O que é

Bloco sólido que fica intangível **enquanto o dash está ativo**. Dá ao dash uma
segunda função: hoje ele é distância e recarga; com o bloco de fase ele vira
chave.

Os 0,14 s de `DASH_TIME` a 232 px/s cobrem 32 px — quatro tiles. Uma parede de
fase pode ter no máximo **3 tiles de espessura** para caber com margem; 4 é o
limite absoluto e não deve ser usado em sala obrigatória.

O risco central da mecânica: o dash acabar dentro do bloco. Isso **tem** que ter
resposta definida, e a escolhida é empurrar para fora na direção do dash (ver
§5). Deixar o Godot resolver a sobreposição produz um empurrão em direção
arbitrária, o que lê como bug.

## 2. Salas novas no modo história — 5

Depois de FIRST DASH e da sala que ensina cristal de dash.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `phase_first` — ATRAVESSE | que o dash passa | Parede de `p` de 2 tiles cortando a sala inteira, chão dos dois lados. Impossível errar. |
| 2 | `phase_choice` — DUAS PORTAS | fase como atalho | Rota longa por cima, rota curta por dentro de duas paredes de `p`. |
| 3 | `phase_crystal` — CADEIA | recarga entre paredes | Três paredes de `p` com cristais `d` nos vãos; sem os cristais só dá para atravessar uma. |
| 4 | `phase_trap` — DENTRO | o que acontece se falhar | Parede de 3 tiles com espaço curto do outro lado; o dash mal alcança. Ensina o limite. |
| 5 | `phase_gems` — DESVIO | gema atrás da fase | Duas gemas normais na rota, a terceira atrás de `p` num nicho fechado. |

```gdscript
## Uma parede, dois chãos. A sala é uma pergunta de uma palavra.
static func _level_phase_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 30, 20, 2, 7, "p")
	puts(g, [Vector2i(20, 26), Vector2i(40, 26), Vector2i(48, 24)], "o")
	put(g, 4, 26, "P")
	put(g, 52, 26, "X")
	return bake(g)
```

**Par sugerido:** 22 s, 40 s, 48 s, 44 s, 50 s.

## 3. Modo infinito

```gdscript
## Uma parede de fase atravessando a rota. O caminho por cima existe sempre —
## no infinito o bloco é atalho, nunca portão, porque o gerador não sabe provar
## que o jogador tem dash disponível naquele ponto.
static func _phase(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(9, 11), room)
	var th := 2
	Levels.rect(g, x + w / 2, STAND - 3, th, 4, "p")
	spots.append(Vector2i(x + w / 2, STAND - 5))
	return w
```

Note o `STAND - 3`: a parede tem 4 de altura e o topo dela fica a 3 tiles do
chão, então **saltar por cima é sempre possível** (o pulo sobe 4,7). Essa é a
guarda que torna o segmento seguro sem precisar simular o dash.

| Tabela | Valor |
| --- | --- |
| `UNLOCK["phase"]` | 11 |
| `THREAT["phase"]` | 1.0 (é atalho, não ameaça) |
| `WIDTHS["phase"]` | 9 |
| `TASTE["phase"]` | 1.5 |

**Impacto:** cria rota de skill. Dois jogadores na mesma sala fazem tempos bem
diferentes, o que é exatamente o que o passo 10 (combo/score) quer medir.

## 4. Codex

```gdscript
{"id": "phase", "kind": WORLD, "sprite": "phase_block"},
"p": "phase",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `PHASE BLOCK` | `SOLID, EXCEPT TO A DASH. THREE TILES IS THE LIMIT` |
| PT | `BLOCO DE FASE` | `SOLIDO, MENOS PARA O DASH. TRES TILES E O LIMITE` |
| ES | `BLOQUE DE FASE` | `SOLIDO, SALVO PARA EL DASH. TRES TILES ES EL LIMITE` |

**Sprite:** roxo (`Palette.PURPLE`) com hachura diagonal e borda pontilhada — a
borda pontilhada é o que diz "não é parede de verdade". Enquanto o player está
em dash, os blocos ficam translúcidos (`modulate.a = 0.35`), o que dá o feedback
de que a passagem está aberta.

## 5. Para o agente

**Arquivos**
1. `scripts/phase_block.gd` — `StaticBody2D` de 1 tile ligado ao estado do
   player. Em vez de cada bloco perguntar ao player todo frame, `Level` conecta:

```gdscript
# player.gd
signal dash_changed(active: bool)   # emitido em _try_dash() e no fim de _tick_dash()

func is_dashing() -> bool:
	return _dash > 0.0
```

2. `level.gd` — cria os blocos, conecta o sinal, e resolve a saída:

```gdscript
func _on_dash_changed(active: bool) -> void:
	for block in _phase_blocks:
		block.set_solid(not active)
	if not active:
		_eject_from_phase()
```

3. `_eject_from_phase()` — o coração do passo:

```gdscript
## O dash acabou. Se o player parou dentro de um bloco, empurra na direção em
## que ele estava indo até sair, no máximo 4 tiles. Se não couber, mata: ficar
## preso é pior do que morrer, porque não tem saída nem explicação.
func _eject_from_phase() -> void:
	var p := _player
	var dir := p.velocity.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2(p.facing, 0)
	for step in 32:
		if not _overlaps_phase(p.global_position):
			return
		p.global_position += dir * 2.0
	p.kill()
```

4. `pixel_art.gd`, `codex.gd`, `i18n.gd`, `levels.gd`, `level_gen.gd`.

**Armadilhas**
- A colisão deve voltar **depois** da ejeção, não antes, senão o
  `move_and_slide()` do frame seguinte empurra o player de novo. Usar
  `set_deferred("disabled", ...)` e ordenar: ejetar, depois religar.
- Dash diagonal para baixo dentro de um bloco no chão: a ejeção segue a
  diagonal e pode enfiar o player no terreno normal. Por isso o limite de 32
  passos e o `kill()` no fim — testar esse caso explicitamente.
- O cristal `d` recarrega o dash no ar. Dentro de um bloco de fase isso permite
  um dash novo a partir de dentro, o que é uma jogada legítima. Não bloquear.
- **`verify_rooms.py` não simula dash direcional com precisão suficiente para
  provar travessia de fase.** Marcar as salas de fase com uma flag que diz ao
  checker "esta rota depende de dash" e validar à mão. Alternativa: garantir que
  toda sala de fase tem rota alternativa (o infinito garante; a campanha não
  deve).
- Espelhamento: `p` é simétrico, nada a fazer.

**Critérios de aceite**
- Dash atravessa 3 tiles de `p`; parede de 4 falha de forma consistente.
- Nenhum caso de player preso dentro de bloco, em 50 tentativas de dash torto.
- Fora do dash, `p` se comporta exatamente como `#`.
