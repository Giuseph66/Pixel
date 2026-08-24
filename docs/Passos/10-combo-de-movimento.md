# 10 — Combo de movimento

**Fase:** 1 · **Tile:** nenhum · **Custo:** médio-baixo · **Depende de:** nada

## 1. O que é

Enquanto o jogador não toca o chão, cada **verbo diferente** que ele usa
(dash, wall jump, stomp, mola, queda esmagadora que não termina no chão) soma
ao combo. Tocar o chão zera. O combo vira pontuação e vira barulho na tela.

O jogo já tem metade disso: `player.gd:_chain` conta stomps consecutivos e dá
impulso crescente (`CHAIN_STEP`, `CHAIN_MAX`). O combo generaliza aquele
contador para todos os verbos aéreos e o expõe.

**Verbos distintos, não repetições.** Dash + dash + dash não é combo 3 — o dash
só recarrega em parede, stomp ou cristal, então repetir já implica outro verbo
no meio. Contar verbos distintos evita inflacionar e premia variedade, que é o
que a mecânica quer ensinar.

```gdscript
# player.gd
enum Verb { DASH, WALL, STOMP, SPRING, POUND }
signal combo_changed(count: int, verb: int)
```

**Pontuação:** `score += 100 * combo * combo` ao aterrissar, ou seja, um combo
5 vale 2500 e um combo 2 vale 400. Curva quadrática porque a dificuldade de
manter o combo também é.

## 2. Salas novas no modo história — 3

Salas opcionais, no fim da campanha, desenhadas como playground e não como
teste. O combo é sistema de expressão; sala que **exige** combo vira sala de
execução perfeita, que já existe de sobra.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `combo_yard` — PATIO | que os verbos se somam | Sala aberta, sem ameaça: duas paredes, três slimes, uma mola, dois cristais. Rota trivial pelo chão; a rota alta dá combo 6. |
| 2 | `combo_gap` — TRAVESSIA | manter o combo sob pressão | Vão largo com `^` no fundo; atravessar sem tocar o chão é possível de 4 formas diferentes. |
| 3 | `combo_tower` — SUBIDA LIMPA | combo como rota vertical | Torre onde a rota do chão é longa e a rota de combo é curta; o par premia a segunda. |

```gdscript
## Nada aqui mata. A sala existe para o jogador descobrir do que é capaz.
static func _level_combo_yard() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 12, 10, 2, 14, "#")          # parede esquerda para wall jump
	rect(g, 46, 10, 2, 14, "#")          # e a da direita
	puts(g, [Vector2i(20, 26), Vector2i(30, 26), Vector2i(40, 26)], "S")
	put(g, 30, 26, "J")
	puts(g, [Vector2i(24, 16), Vector2i(36, 16)], "d")
	puts(g, [Vector2i(16, 8), Vector2i(30, 6), Vector2i(44, 8)], "o")
	put(g, 4, 26, "P")
	put(g, 54, 26, "X")
	return bake(g)
```

**Par sugerido:** 30 s, 38 s, 40 s.

## 3. Modo infinito

O combo é a **pontuação** do infinito, que hoje não tem nenhuma além de
profundidade e gemas. Isso muda o que uma run significa: dá para ir fundo
devagar ou ir raso com estilo, e as duas coisas rendem um número.

- Score acumulado da run mostrado no HUD e em `ending_screen.gd`.
- Recorde novo no save: `endless_score`, `endless_best_combo`.
- Nada muda na geração. Os segmentos existentes (`spring`, `climb`, `nest`,
  `ferry`) já dão material de combo de sobra.

Opcional, se render: um bônus de sala por terminar sem tocar o chão depois de
um ponto — mas isso exige que `LevelGen` garanta a rota aérea, o que ele hoje
não faz. Deixar de fora da primeira versão.

## 4. Codex / apresentação

```gdscript
{"id": "combo", "kind": ABILITY, "sprite": "icon_combo"},
```

Descoberto na primeira vez que o combo passar de 2.

| Idioma | name | text |
| --- | --- | --- |
| EN | `COMBO` | `CHAIN DIFFERENT MOVES IN THE AIR. THE FLOOR RESETS IT` |
| PT | `COMBO` | `ENCADEIE MOVIMENTOS NO AR. O CHAO ZERA TUDO` |
| ES | `COMBO` | `ENCADENA MOVIMIENTOS EN EL AIRE. EL SUELO LO CORTA` |

**Na tela:** o número do combo aparece perto do player (`fx.popup()`, que já
existe e já é usado pelo "+1" da gema), crescendo de tamanho com a contagem. O
HUD ganha o score total à direita, na faixa de 14 px que já existe. Cores:
`CYAN` até 3, `GOLD` de 4 a 6, `WHITE` acima.

## 5. Para o agente

**Arquivos**
1. `player.gd`
   - `var _combo_verbs := 0` (bitmask de `Verb`), `var combo := 0`;
   - cada verbo marca seu bit e reconta:

```gdscript
func _add_verb(verb: int) -> void:
	var bit := 1 << verb
	if _combo_verbs & bit:
		return
	_combo_verbs |= bit
	combo += 1
	combo_changed.emit(combo, verb)
```

   - chamadas: `_try_dash()` → `DASH`; ramo de wall jump em `_handle_jump()` →
     `WALL`; `stomp()` → `STOMP`; `spring_bounce()` → `SPRING`;
     `_land_pound()` **não** (termina no chão).
   - reset onde `_chain = 0` já acontece: no `is_on_floor()` do
     `_physics_process()`. Emitir `combo_changed(0, -1)` antes de zerar para que
     o `Level` possa pontuar.
2. `level.gd` — conecta `combo_changed`, acumula `score`, chama
   `fx.popup()`, e passa o total no sinal `completed` (que hoje leva
   `time, gems, total_gems` — adicionar `score` significa mexer nos dois
   receptores em `main.gd`).
3. `hud.gd` — score à direita; `results_screen.gd` — linha de score e melhor
   combo.
4. `save_manager.gd` — `endless_score`, `endless_best_combo`, e por sala
   `best_combo` se quiser (barato, e casa bem com as medalhas do passo 08).

**Armadilhas**
- **Manter o `_chain` existente.** Ele controla o impulso crescente do stomp e é
  outra coisa: `_chain` conta repetições do mesmo verbo, `combo` conta verbos
  distintos. Não fundir os dois; comentar a diferença no código, porque a
  próxima pessoa vai querer fundir.
- Wall slide **não** conta. Só o wall jump. Encostar na parede é gratuito e
  contaria em toda subida.
- O reset acontece em `is_on_floor()`, que também é verdadeiro no primeiro frame
  do respawn — emitir com combo 0 nesse frame gera popup fantasma. Guardar com
  `if combo > 0`.
- Plataforma móvel é chão. Aterrissar nela zera. Correto, e precisa estar no
  texto do codex? Não — o jogador descobre em 2 s.

**Critérios de aceite**
- Dash + wall jump + stomp sem tocar o chão marca combo 3 e 900 pontos.
- Tocar qualquer chão zera o combo e credita a pontuação uma vez só.
- O impulso crescente do stomp continua idêntico ao de hoje.
