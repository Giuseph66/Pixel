# 19 — Impulso de parede

**Fase:** 2 · **Tile:** nenhum · **Custo:** baixo

## 1. O que é

Wall jump executado nos primeiros ~5 frames de contato com a parede sai com
25 % mais velocidade horizontal. Encostar, esperar e pular continua funcionando
exatamente como hoje — o impulso é um bônus por precisão, nunca um requisito.

```gdscript
# player.gd
const WALL_WINDOW := 0.09       # ~5 frames a 60fps, mesma ordem do COYOTE_TIME
const WALL_BOOST := 1.25        # 152 -> 190 px/s na horizontal
```

É a mecânica mais barata da lista inteira e uma das que mais mudam o teto de
habilidade: a diferença entre um wall jump preguiçoso e um preciso passa a
aparecer no cronômetro. Combina diretamente com o passo 10 (combo) e com o
passo 08 (medalha de tempo), porque dá ao jogador experiente uma forma de
ganhar tempo sem mudar de rota.

Regra de leitura: o impulso **tem** que ser visível. Partícula diferente
(`Palette.WHITE` em vez de `CYAN`), som meio tom acima, e um rastro curto. Sem
isso o jogador sente que o jogo é inconsistente em vez de perceber que acertou.

## 2. Salas novas no modo história — 3

Depois de THE CLIMB (a sala que ensina wall jump).

| # | Id / nome | Ensina | Esboço |
| --- | --- | --- | --- |
| 1 | `boost_first` — TOQUE CERTO | a janela | Poço com paredes a 6 tiles de distância — a travessia de wall jump só fecha com o impulso. Fundo sem espinho: errar custa tempo, não vida. |
| 2 | `boost_zigzag` — ZIGUE | vários impulsos seguidos | Chaminé de 5 andares em zigue-zague; cada par de paredes um pouco mais afastado que o anterior. |
| 3 | `boost_gap` — SALTO LONGO | impulso como distância, não altura | Vão horizontal atravessado saindo de uma parede: com impulso alcança a borda, sem impulso cai numa plataforma de socorro (que custa 4 s). |

```gdscript
## Paredes a seis tiles. Sem o impulso o zigue-zague não fecha, mas errar aqui
## nunca mata: o fundo é chão limpo e a subida recomeça.
static func _level_boost_first() -> PackedStringArray:
	var g := blank()
	rect(g, 0, 27, COLS, 5, "#")
	rect(g, 22, 4, 2, 23, "#")
	rect(g, 34, 4, 2, 23, "#")
	puts(g, [Vector2i(25, 20), Vector2i(32, 14), Vector2i(25, 8)], "o")
	put(g, 4, 26, "P")
	put(g, 28, 3, "X")
	return bake(g)
```

**Par sugerido:** 30 s, 45 s, 40 s.

## 3. Modo infinito

**Nenhum segmento novo, nenhuma tabela alterada.**

O efeito no infinito é de teto, não de piso: os segmentos `climb`, `tower` e
`nest` ficam mais rápidos para quem domina a janela, e idênticos para quem não
domina. Como a pontuação de run (passo 10) mede tempo e combo, o impulso vira
uma das principais fontes de diferença entre duas runs na mesma seed — que é
exatamente o que um modo infinito com recordes quer.

Um ajuste opcional, depois de medir: se o impulso encurtar demais as salas de
`climb`, subir `THREAT["climb"]` de 1.0 para 1.2. Não fazer preventivamente.

## 4. Codex

Não cria entrada nova — é uma propriedade do wall jump, e a entrada `wall` já
existe. Atualizar o texto dela:

| Idioma | text novo |
| --- | --- |
| EN | `TOUCH A WALL TO CLING. JUMP AT ONCE AND YOU LEAVE FASTER` |
| PT | `ENCOSTE NA PAREDE PRA GRUDAR. PULE NA HORA E SAI MAIS RAPIDO` |
| ES | `TOCA EL MURO PARA COLGARTE. SALTA YA Y SALES MAS RAPIDO` |

Passa de 48 para ~57 caracteres. Conferir a largura em `codex_screen.gd` antes
de fechar — se não couber, quebrar em duas linhas ou encurtar
(`PT: ENCOSTE E PULE NA HORA PRA SAIR MAIS RAPIDO`).

## 5. Para o agente

**Implementação em `player.gd`.** O estado de parede já existe (`_wall_dir`,
recalculado todo frame em `_apply_gravity()`); falta só saber há quanto tempo:

```gdscript
var _wall_time := 0.0

# no fim de _apply_gravity(), depois de _wall_dir ser decidido:
	if _wall_dir != 0:
		_wall_time += delta
	else:
		_wall_time = 0.0
```

e no ramo de wall jump de `_handle_jump()`:

```gdscript
		elif _wall_dir != 0:
			var perfect := _wall_time <= WALL_WINDOW
			velocity.y = WALL_JUMP.y
			velocity.x = -_wall_dir * WALL_JUMP.x * (WALL_BOOST if perfect else 1.0)
			if perfect:
				_found("boost")
				Audio.play_varied("wall_jump", 0.12)   # tom acima
				fx.emit(_fx_at(...), 10, Palette.WHITE, 100.0, ...)
```

**Armadilhas**
- **`_wall_time` tem que ser incrementado depois do cálculo de `_wall_dir`, não
  antes.** Invertido, o primeiro frame de contato já conta 1 delta e a janela
  fica 1 frame mais curta do que a constante diz.
- O `WALL_CLING` empurra o player contra a parede durante o slide; isso não
  afeta `_wall_time`, mas afeta a sensação da janela em quedas rápidas. Testar
  chegando na parede a `MAX_FALL`.
- Não aplicar o boost à componente vertical. Wall jump mais alto muda a
  alcançabilidade de todas as salas existentes; wall jump mais rápido na
  horizontal quase não muda (as chaminés são estreitas).
- `verify_rooms.py` deve usar o wall jump **sem** boost ao validar as 21 salas
  atuais (elas continuam válidas) e **com** boost para as 3 novas. Um parâmetro
  no checker.
- A entrada `boost` no codex é opcional — se não criar, remover o `_found()`.

**Critérios de aceite**
- Wall jump imediato sai a 190 px/s; wall jump depois de 0,2 s sai a 152.
- O impulso é audível e visível.
- As 21 salas atuais continuam com os mesmos tempos de referência.
