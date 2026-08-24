# 25 — Fantasma do recorde pessoal

**Fase:** 3 · **Tile:** nenhum · **Custo:** médio · **Bloqueio:** formato de armazenamento

## 1. O que é

A corrida que estabeleceu o melhor tempo de uma sala fica gravada e é
reproduzida como um fantasma translúcido quando o jogador volta àquela sala.
Correr contra si mesmo transforma um tempo em oponente.

É a melhor mecânica de rejogabilidade da lista para um jogo cronometrado — e
a única cujo bloqueio é de **armazenamento**, não de design.

## 2. Salas novas no modo história — 0

Nenhuma. Vale para as 21 existentes e para toda sala nova que vier.

Onde aparece:
- na sala, como sprite translúcido;
- em `results_screen.gd`, a diferença para o fantasma (`-1.4 S` em verde,
  `+0.8 S` em vermelho);
- em `level_select.gd`, um marcador nas salas que já têm fantasma gravado.

**Interação com as medalhas (passo 08):** o fantasma da corrida que ganhou a
medalha de tempo é o mais útil de guardar — não necessariamente o mais rápido,
se as regras divergirem. Guardar o do melhor tempo é mais simples e quase sempre
o mesmo; ficar com o mais simples.

## 3. Modo infinito

**Não.** As salas do infinito são geradas por seed e profundidade; um fantasma
só valeria para a mesma seed, que o jogador nunca joga duas vezes de propósito.

Uma variante que funcionaria, se algum dia houver "seed do dia": todo mundo joga
a mesma seed, e o fantasma é o do próprio jogador na tentativa anterior. Fica
anotado como ideia para um modo diário, fora deste passo.

## 4. Codex / apresentação

Sem entrada de codex. Texto:

| Chave | EN | PT | ES |
| --- | --- | --- | --- |
| `ghost.title` | `YOUR BEST` | `SEU RECORDE` | `TU RECORD` |
| `ghost.ahead` | `AHEAD BY %s` | `NA FRENTE POR %s` | `DELANTE POR %s` |
| `ghost.behind` | `BEHIND BY %s` | `ATRAS POR %s` | `DETRAS POR %s` |
| `ghost.none` | `NO GHOST YET` | `SEM FANTASMA AINDA` | `SIN FANTASMA AUN` |

**Visual:** sprite do player em `Palette.CYAN_DARK` a 40 % de opacidade, sem
partículas, sem som, sem colisão. Um fantasma que faz barulho ou solta poeira
compete com o jogador pela atenção; ele tem que ser leitura periférica.

## 5. Para o agente

### 5.1 O bloqueio: quanto ocupa

| Taxa | Corrida de 60 s | 21 salas | × 3 slots |
| --- | --- | --- | --- |
| 60 Hz, floats em JSON | 3600 pts ≈ 90 KB | 1,9 MB | 5,7 MB |
| 20 Hz, inteiros em JSON | 1200 pts ≈ 14 KB | 300 KB | 900 KB |
| 20 Hz, binário (2×int16) | 1200 pts = 4,8 KB | 100 KB | 300 KB |

`saves.json` hoje tem alguns KB e é reescrito inteiro a cada `save_game()` —
que é chamado em `discover()`, ou seja, durante o jogo. Enfiar fantasmas nele
significa serializar centenas de KB no meio de uma sala. **Não fazer.**

**Decisão: arquivos binários separados**, um por sala por slot:

```
user://ghosts/<slot>_<room_id>.gst
```

```gdscript
# ghost_store.gd
const SAMPLE_HZ := 20
const MAGIC := 0x47535431        # "GST1"

static func save(slot: int, room_id: String, samples: PackedVector2Array) -> void:
	var f := FileAccess.open(_path(slot, room_id), FileAccess.WRITE)
	if f == null:
		return
	f.store_32(MAGIC)
	f.store_16(samples.size())
	for p in samples:
		f.store_16(int(clampi(roundi(p.x), 0, 65535)))
		f.store_16(int(clampi(roundi(p.y), 0, 65535)))
	f.close()
```

Posições cabem em `int16` sem sinal: a sala tem 480×256 px. Interpolar entre
amostras na reprodução (`lerp` a 20 Hz é suave o bastante para um fantasma).

**Teto:** limitar a 90 s de gravação (1800 amostras, 7,2 KB). Corrida mais longa
que isso não vira fantasma — e uma sala de 90 s não é uma sala em que o
fantasma ajuda.

### 5.2 Fluxo

1. `Level` grava enquanto joga: a cada `1.0 / SAMPLE_HZ` acumulado, empilha
   `_player.global_position`.
2. `main.gd:_on_room_completed()` — se `Save.record_clear()` devolveu `true`
   (novo recorde), chama `GhostStore.save()`.
3. `Level._ready()` — carrega o fantasma da sala, se existir, e cria um
   `GhostPlayer` (`Node2D` com `Sprite2D`, sem corpo físico).
4. `restart()` — o fantasma reinicia junto com a sala, do começo.

### 5.3 Armadilhas

- **Depende do id estável de sala** (passo 00 §4.4). Com índices, inserir uma
  sala faz o fantasma da sala 5 aparecer na 6. Não implementar antes.
- A gravação é da tentativa **que terminou**, não do acumulado desde que a sala
  abriu. Zerar o buffer em `restart()`.
- O fantasma não deve ter colisão, sombra, som nem partícula. Só o sprite.
- Se o arquivo estiver corrompido ou de uma versão antiga (`MAGIC` diferente),
  ignorar em silêncio e apagar. Um fantasma quebrado nunca pode impedir a sala
  de abrir.
- Salas remixadas (passo 11) têm fantasma próprio: a chave já tem o prefixo
  `"r"` e o caminho do arquivo segue.
- Modo com modificadores ou habilidades diferentes gera fantasmas
  incomparáveis. Como os modificadores são só do infinito e o infinito não tem
  fantasma, isso não é problema hoje — mas anotar, porque muda se o passo 20
  for estendido ao remix.
- Deletar o slot (`reset_slot()`) tem que apagar os fantasmas dele. É o único
  lugar onde o save deixa lixo fora do JSON.

### 5.4 Critérios de aceite

- Bater o recorde grava; jogar de novo mostra o fantasma da corrida anterior.
- Arquivo de sala de 60 s ocupa < 6 KB.
- Apagar o slot apaga os fantasmas.
- Fantasma corrompido não impede a sala de carregar.
