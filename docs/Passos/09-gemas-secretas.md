# 09 — Gemas secretas

**Fase:** 1 · **Tile:** `O` · **Custo:** baixo · **Depende de:** [08](08-medalhas.md) (para aparecer no selo)

## 1. O que é

Uma quarta gema por sala, escondida atrás de uma rota que a rota normal não
passa: um teto quebrável, um wall jump de mais, um dash na diagonal por cima da
sala. Vale como coleção, **não** conta para abrir a porta.

O motivo de ser um tile separado e não uma gema comum bem escondida: a porta
usa `charge = gems_taken / gems_total` para se preencher visualmente
(`level.gd:_update_door_charge()`). Uma gema muito difícil dentro dessa conta
faz a porta parecer incompleta para sempre, o que lê como bug.

Regra de desenho: a gema secreta nunca é obrigatória e nunca fica no caminho.
Se o jogador pega sem querer, ela não era secreta.

## 2. Salas novas no modo história — 0 (mas altera 8)

Zero salas novas. Oito das 21 salas ganham uma `O`. Escolher as que têm espaço
morto — sala 1 (o degrau alto à direita), sala 3 (acima do teto de espinhos),
sala 6 (topo do poço de wall jump) e assim por diante.

**Distribuição sugerida:** 8 secretas na campanha atual, e mais uma por sala
nova das mecânicas seguintes que tenha espaço para isso. Não colocar em todas
— a raridade é metade do valor.

| Sala | Onde | Rota |
| --- | --- | --- |
| 1 FIRST STEPS | canto superior direito, acima do último degrau | pulo do degrau + wall jump na parede da sala |
| 3 PRICKLY | acima do teto de espinhos | dash diagonal pelo vão da direita |
| 6 THE CLIMB | topo do poço | dois wall jumps além do necessário |
| 12 (par 90 s) | atrás do bloco `k` do fundo | queda esmagadora fora da rota |

As outras quatro ficam a critério de quem desenhar, com a mesma regra.

## 3. Modo infinito

Uma `O` por sala, a partir de `depth >= 3`, colocada com a mesma lógica de
`_place_crystals()` (que já procura ar livre) mas com preferência pelo **canto
mais alto** disponível:

```gdscript
static func _place_secret(g: Array, rng: RandomNumberGenerator, depth: int) -> void:
	if depth < 3:
		return
	var best := Vector2i(-1, -1)
	var tries := 0
	while tries < 80:
		tries += 1
		var x := rng.randi_range(START_X, END_X - 1)
		var y := rng.randi_range(3, STAND - 6)
		if not _clear_air(g, x, y):
			continue
		if best.x < 0 or y < best.y:
			best = Vector2i(x, y)
	if best.x >= 0:
		Levels.put(g, best.x, best.y, "O")
```

**Impacto:** dá ao infinito uma métrica de rota além da profundidade. Uma run de
20 salas com 20 secretas é uma run muito diferente de 20 salas correndo, e as
duas viram recordes separados (`endless_secrets` no save). Não muda a
dificuldade das salas — a gema nunca bloqueia nada.

## 4. Codex

```gdscript
{"id": "secret", "kind": COLLECTIBLE, "sprite": "gem_secret"},
"O": "secret",
```

| Idioma | name | text |
| --- | --- | --- |
| EN | `SECRET GEM` | `ONE PER ROOM, OFF THE ROUTE. THE DOOR IGNORES IT` |
| PT | `GEMA SECRETA` | `UMA POR SALA, FORA DA ROTA. A PORTA NAO LIGA` |
| ES | `GEMA SECRETA` | `UNA POR SALA, FUERA DE RUTA. LA PUERTA NI SE ENTERA` |

**Sprite:** o `gem` existente com a paleta `PURPLE`/`WHITE` e um pixel de
brilho a mais. Precisa ser óbvio que é outra coisa no instante em que aparece
na tela, porque geralmente aparece de relance.

**Nota de descoberta:** `_discover_contents()` abre a página do codex ao **ver**
o tile na sala, o que aqui entregaria a existência de secretas na primeira sala
que tiver uma. Isso é bom (o jogador precisa saber que elas existem para
procurar) — mas a página só deve abrir quando a gema estiver realmente visível
na tela. Como quase sempre está (a sala inteira cabe na tela), manter o
comportamento padrão.

## 5. Para o agente

**Arquivos**
1. `scripts/gem.gd` — um `secret := false` e o sprite trocado, ou um
   `SecretGem` de 20 linhas. Recomendação: flag no `Gem`, porque o
   comportamento é idêntico (bob, área, `collected`).
2. `level.gd`
   - caso `"O"` em `_spawn_entities()`: cria a gema com `secret = true` e
     **não** incrementa `gems_total`;
   - `_on_gem_collected()` separa a contagem:

```gdscript
func _on_gem_collected(gem: Gem) -> void:
	if gem.secret:
		secrets_taken += 1
		Save.add_secret()
		Audio.play("gem", 1.35)      # nota mais alta: soa diferente
	else:
		gems_taken += 1
		Save.add_gem()
		...
	_update_door_charge()            # só muda quando não é secreta
```

3. `save_manager.gd` — `"secrets": {}` por sala (bitmask não; basta `true`),
   `secret_count()`, e `endless_secrets`.
4. `hud.gd` — não mostrar contador de secretas durante o jogo. Mostrar
   estragaria a busca; o lugar dela é a tela de resultado e o seletor de salas.
5. `results_screen.gd` / `level_select.gd` — um losango roxo quando a sala tem
   a secreta pega.

**Armadilhas**
- `_update_door_charge()` divide por `gems_total`. Se a secreta entrar nessa
  conta por engano, a porta nunca completa. É o bug óbvio deste passo.
- `Save.add_gem()` alimenta o contador vitalício `gems_taken`. Secretas
  precisam de contador próprio, senão a estatística de "gemas" fica sem
  significado.
- Espelhamento (passo 11) move a secreta junto — de propósito, e é bom: a
  mesma sala espelhada exige redescobrir a rota.
- Se a secreta ficar atrás de um bloco `k`, ela só é alcançável depois que o
  jogador tem a queda esmagadora. No modo história isso trava a coleta em salas
  iniciais. Aceitar (é motivo para voltar) e não colocar secreta atrás de
  habilidade nas 5 primeiras salas.

**Critérios de aceite**
- Pegar a secreta não mexe na carga da porta.
- O contador de secretas persiste por sala e por slot.
- Nenhuma sala fica impossível de terminar sem a secreta.
