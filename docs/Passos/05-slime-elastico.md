# 05 — Slime elástico

**Fase:** 1 · **Tile:** `e` · **Custo:** baixo · **Depende de:** nada

## 1. O que é

Um slime que não morre pisado: devolve o impulso de mola e continua andando.
É uma `J` (mola) que se move, o que muda a leitura do stomp — hoje pisar é
sempre "eliminar", e aqui pisar é "usar".

```gdscript
# elastic_slime.gd (variante de slime.gd)
# usa player.spring_bounce(), que já existe e já dá SPRING_VELOCITY := -450.0
```

450 px/s de subida são ~14 tiles: um elástico embaixo de uma plataforma alta é
um elevador. Como ele anda, o ponto de embarque muda com o tempo — o mesmo
recurso da plataforma circular, mas com uma coisa que também mata pelo lado.

**Ele mata por contato lateral**, igual ao slime comum. Isso é essencial: sem
o risco, ele vira móvel, não inimigo.

## 2. Salas novas no modo história — 4

Entram depois de SLIME TIME e de BOUNCE (o jogador precisa conhecer as duas
peças que o elástico funde).

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `elastic_first` — MOLA VIVA | que ele não morre e lança | Sala rasa, um `e` andando num piso de 20 tiles, saída numa plataforma a 8 tiles de altura. Sem outra rota. |
| 2 | `elastic_timing` — CARONA ALTA | mirar o ponto de encontro | O `e` anda entre duas paredes; a plataforma de saída fica só sobre uma metade do percurso. |
| 3 | `elastic_chain` — SEQUENCIA | dois lançamentos seguidos | Dois `e` em alturas diferentes; o primeiro joga na altura do segundo. Combina com o super stomp (o chain de `player.gd` conta os dois). |
| 4 | `elastic_spike` — SEM CHAO | elástico como único piso | Piso quase todo `^`; o `e` patrulha uma faixa segura e é a única forma de ganhar altura. |

```gdscript
## O elástico é o elevador. Não há degrau nenhum até a porta.
static func _level_elastic_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	put(g, 22, 26, "e")
	rect(g, 34, 18, 12, 2, "#")          # ~8 tiles acima do piso
	put(g, 40, 17, "o")
	put(g, 4, 26, "P")
	put(g, 42, 17, "X")
	return bake(g)
```

**Par sugerido:** 28 s, 38 s, 46 s, 55 s.

## 3. Modo infinito

```gdscript
## Um elástico numa faixa de chão limpo. Vale como ameaça E como rota: é o
## primeiro segmento do jogo que o jogador pode querer que apareça.
static func _elastic(g: Array, rng: RandomNumberGenerator, x: int, room: int,
		spots: Array[Vector2i]) -> int:
	var w := mini(rng.randi_range(7, 10), room)
	Levels.put(g, x + w / 2, STAND, "e")
	spots.append(Vector2i(x + w / 2, STAND - 7))   # gema alta: só de carona
	return w
```

| Tabela | Valor |
| --- | --- |
| `UNLOCK["elastic"]` | 9 |
| `THREAT["elastic"]` | 3.0 (mesmo do slime: mata igual pelo lado) |
| `WIDTHS["elastic"]` | 7 |
| `TASTE["elastic"]` | 1.8 |

**Impacto:** é o primeiro segmento que dá **mobilidade vertical** de graça no
infinito, então salas fundas ganham uma rota alta que não existia. Colocar a
gema do `spots` em `STAND - 7` explora isso e recompensa quem usa o elástico
em vez de contorná-lo.

## 4. Codex

```gdscript
{"id": "elastic", "kind": CREATURE, "sprite": "elastic_a"},
"e": "elastic",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `ELASTIC` | `STOMP IT AND IT THROWS YOU BACK. IT NEVER DIES` |
| PT | `ELASTICO` | `PISE E ELE TE JOGA PRA CIMA. NAO MORRE` |
| ES | `ELASTICO` | `PISALO Y TE LANZA. NUNCA MUERE` |

**Sprites:** `elastic_a`/`elastic_b` — o slime com a paleta da mola
(`Palette.GOLD` no corpo) e uma faixa clara no topo. Precisa ser distinguível
do `slime_a` a 8 px e à distância; a cor faz esse trabalho, a silhueta não
consegue.

## 5. Para o agente

**Arquivos**
1. `scripts/elastic_slime.gd` — copiar `slime.gd` e mudar só o ramo do stomp:

```gdscript
	if _approached_from_above:
		player.spring_bounce()
		_squash()          # feedback visual; ele sobrevive
	else:
		player.kill()
```

2. `level.gd:_spawn_entities()` — caso `"e"`, com o mesmo wiring de `Slime`
   (`is_wall`, `is_ground`, `speed_scale`) **e** o `player` injetado em
   `_discover_contents()`, que hoje só faz isso para `Slime`:

```gdscript
	for child in _entities.get_children():
		if child is Slime:
			(child as Slime).player = _player
		elif child is ElasticSlime:
			(child as ElasticSlime).player = _player
```

Esta é a linha mais fácil de esquecer do passo inteiro — sem ela, o elástico
existe, anda e não interage com nada.

3. `pixel_art.gd`, `codex.gd`, `i18n.gd`, `levels.gd`, `level_gen.gd`.

**Armadilhas**
- **Queda esmagadora:** `level.gd:_on_player_pounded()` mata `Slime` e `Bat` num
  raio. O elástico **não** pode entrar nessa lista, senão o pound vira o botão
  de apagar a rota da sala. Deixar de fora e comentar o porquê.
- `player.spring_bounce()` já zera o dash e recarrega — igual à mola. Nada a
  fazer.
- O chain de super stomp (`_chain` em `player.gd`) é incrementado por
  `stomp()`, não por `spring_bounce()`. Sala 3 depende disso: decidir se o
  elástico soma ao chain. **Recomendação: não soma** — a mola nunca somou, e
  duas fontes de impulso com regras diferentes é o que mantém as duas úteis.
- Copiar `slime.gd` significa copiar a detecção manual de colisão dele. Ler o
  comentário no topo daquele arquivo antes de "simplificar" para `Area2D`: a
  escolha é deliberada e por um bug real.

**Critérios de aceite**
- Pisar lança ~14 tiles e o elástico continua andando.
- Encostar de lado mata o player.
- Queda esmagadora em cima dele **não** o mata.
