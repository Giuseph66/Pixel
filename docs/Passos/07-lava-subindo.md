# 07 — Lava subindo

**Fase:** 1 · **Tile:** `A` (marca a linha inicial) · **Custo:** baixo

## 1. O que é

Uma linha mortal que sobe a velocidade constante a partir do fundo da sala. Não
é obstáculo: é o cronômetro virando ameaça. Todo o resto do jogo pune erro de
execução; a lava pune hesitação, que é uma pressão que o jogo ainda não tem.

```gdscript
# lava.gd
const RISE := 9.0               # px/s, ~1,1 tile por segundo
const RISE_MAX := 26.0          # teto quando intensity aperta
```

Uma sala de 32 linhas tem 256 px de altura útil; a 9 px/s a lava leva ~28 s
para varrer tudo, o que é folgado para um par de 40 s e apertado para quem
para. Ela **nunca acelera dentro da sala** — velocidade constante é o que
permite planejar.

Ao morrer, `level.restart()` recria tudo e a lava volta ao início, como
qualquer outra entidade. Nada a fazer.

## 2. Salas novas no modo história — 3

Entram no fim da campanha, como salas-clímax. Antes disso o jogador ainda está
aprendendo verbos, e pressa atrapalha aprendizado.

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `lava_first` — SUBIDA | que ela sobe e não para | Torre vertical simples de plataformas `-` em zigue-zague; nenhuma outra ameaça. |
| 2 | `lava_climb` — SEM PAUSA | subida com wall jump | Poço estreito de paredes `#`; a rota é wall jump contínuo, e parar para respirar custa a corrida. |
| 3 | `lava_gems` — GANANCIA | escolher entre gema e vida | Torre larga com 4 gemas em desvios laterais; pegar todas é possível, com margem de ~2 s. |

```gdscript
## A torre. A lava começa no piso e sobe junto com você.
static func _level_lava_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 29, COLS, 3, "#")
	put(g, 30, 28, "A")                  # linha inicial da lava
	# Zigue-zague até o topo: 8 degraus, ~3 tiles de subida cada.
	var y := 26
	var x := 8
	while y > 6:
		rect(g, x, y, 7, 1, "-")
		x = 8 if x > 30 else 44
		y -= 3
	put(g, 4, 28, "P")
	put(g, 30, 5, "X")
	return bake(g)
```

**Par sugerido:** 35 s, 42 s, 55 s.

## 3. Modo infinito

A lava não é segmento — é **propriedade da sala**, decidida por profundidade:

```gdscript
# em LevelGen.generate(), depois de pintar tudo
if depth >= 12 and (depth + 1) % MILESTONE == 0:
	Levels.put(g, COLS / 2, ROWS - 3, "A")
```

Ou seja: a partir da profundidade 12, **toda sala-marco é uma sala de lava**.
O infinito já usa `MILESTONE := 5` para criar um pico de dificuldade a cada 5
salas; a lava dá a esse pico uma identidade que o jogador reconhece de longe,
em vez de ser "a mesma sala com mais coisas".

Velocidade: `RISE * clampf(intensity, 1.0, 2.2)`, teto em `RISE_MAX`.

**Impacto na curva:** a sala-marco deixa de ser vencível na paciência. É a
mudança de ritmo mais forte que o infinito pode receber por tão pouco código, e
não interfere em nenhum segmento existente.

## 4. Codex

```gdscript
{"id": "lava", "kind": WORLD, "sprite": "lava"},
"A": "lava",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `RISING TIDE` | `IT ONLY GOES UP. THE ROOM HAS AN ENDING TIME NOW` |
| PT | `MARE QUE SOBE` | `SO SOBE. AGORA A SALA TEM HORA PRA ACABAR` |
| ES | `MAREA QUE SUBE` | `SOLO SUBE. LA SALA YA TIENE HORA DE ACABAR` |

**Sprite:** não é tile — é uma faixa desenhada em `_draw()`, largura da sala,
com duas linhas de topo em `Palette.GOLD`/`WHITE` alternando a 8 Hz e o corpo
em `Palette.PURPLE` escurecido. A animação do topo é o que vende o movimento
quando ela está longe.

## 5. Para o agente

**Arquivos**
1. `scripts/lava.gd` — `Node2D` com `_draw()` próprio e uma `Area2D` do tamanho
   da faixa, ou simplesmente um teste de altura por frame:

```gdscript
func _physics_process(delta: float) -> void:
	_surface -= RISE * speed_scale * delta        # sobe = y diminui
	queue_redraw()
	if _player != null and _player.alive \
			and _player.global_position.y + Player.HEIGHT * 0.5 > _surface:
		_player.kill()
```

Teste de altura é melhor que `Area2D` aqui: a faixa é grande, muda de tamanho
todo frame, e a morte tem que ser exata no pixel do topo.

2. `level.gd`
   - caso `"A"` em `_spawn_entities()`: guarda a linha inicial e cria a lava
     **depois** de `_spawn_player()`, porque ela precisa da referência;
   - `z_index` acima do terreno e abaixo do HUD.
3. `level_gen.gd` — a regra de sala-marco do §3.
4. `pixel_art.gd` (paleta, se quiser constantes nomeadas), `codex.gd`, `i18n.gd`,
   `levels.gd`.

**Armadilhas**
- **`verify_rooms.py` não sabe o que é tempo.** Ele faz busca em largura sobre
  alcançabilidade, sem relógio, então vai aprovar salas de lava impossíveis.
  Para essas salas o checker só garante que a rota existe; a margem de tempo
  precisa ser testada à mão. Anotar isso no cabeçalho das 3 salas.
- A lava sobe durante a animação de vitória? Não: `level.gd` já marca
  `finished = true` e para o relógio; usar a mesma flag para congelar a lava,
  senão o jogador morre depois de vencer.
- Pausa: `main.gd` pausa a árvore; `_physics_process` para junto. Nada a fazer,
  mas conferir.
- No infinito, `restart()` recria a lava do zero — o jogador que morre volta ao
  começo da sala com a lava lá embaixo. Correto e intencional.

**Critérios de aceite**
- Sobe 1 tile a cada ~0,9 s com `speed_scale = 1.0`.
- Tocar o topo mata no pixel, não meio tile antes.
- Depois de entrar na porta, a lava congela.
