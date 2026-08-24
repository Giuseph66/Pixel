# 00 — Infra: superfície, força externa, tuning e id de sala

**Fase:** pré-requisito · **Tile:** nenhum · **Custo:** baixo
**Destrava:** 01 gelo, 02 esteiras, 13 vento, 18 pulo carregado, 20
modificadores, 22 gravidade invertida

## 1. O que é

Quatro mudanças pequenas em `player.gd` e `save_manager.gd` que não alteram
nada no jogo (todos os valores nascem neutros) mas que metade dos passos
seguintes precisa para existir. Sem isso, cada mecânica de superfície acaba
enfiando uma referência a `Level` dentro do `Player`, e o acoplamento cresce.

## 2. Salas novas no modo história

Nenhuma. É refactor puro; nada muda na tela.

## 3. Modo infinito

Nenhum impacto direto. `LevelGen` continua igual.

## 4. As quatro peças

### 4.1 Consulta de superfície

`Player` hoje só conhece `fx`. Seguir o padrão que `Slime` já usa
(`is_wall`, `is_ground` como `Callable` injetado por `Level`):

```gdscript
# player.gd
## Injetada por Level antes do player entrar na árvore.
var surface_at: Callable       # func(tx: int, ty: int) -> String

const TILE := 8.0

## Caractere sob os pés, ou "." quando não há chão.
func ground_tile() -> String:
	if not surface_at.is_valid() or not is_on_floor():
		return "."
	var tx := floori(global_position.x / TILE)
	var ty := floori((global_position.y + HEIGHT * 0.5 + 2.0) / TILE)
	return surface_at.call(tx, ty)
```

```gdscript
# level.gd, dentro de _spawn_player()
_player.surface_at = Callable(self, "tile_at")
```

`tile_at()` já existe em `level.gd` e já devolve `"#"` fora da grade, então o
comportamento na borda é o mesmo do resto do jogo.

### 4.2 Força externa

Vento e esteira empurram sem tirar o controle do jogador. Um acumulador
zerado todo frame evita que dois emissores se somem para sempre:

```gdscript
# player.gd
var external_force := Vector2.ZERO   # px/s, somada e zerada a cada frame

func push(force: Vector2) -> void:
	external_force += force
```

Em `_physics_process()`, logo antes de `move_and_slide()`:

```gdscript
	velocity += external_force * delta
	external_force = Vector2.ZERO
```

Somar antes do `move_and_slide()` e depois do bloco de dash/pound significa
que o vento também afeta quem está em dash — decisão de design deliberada:
o dash ignora gravidade, não ignora vento.

### 4.3 Escalas de tuning

`RUN_SPEED`, `GRAVITY_UP`, `GRAVITY_DOWN` e `MAX_FALL` são usados direto. Os
modificadores do infinito (passo 20) precisam escalá-los:

```gdscript
# player.gd
var speed_scale := 1.0
var gravity_scale := 1.0
```

Trocar os usos:

| Antes | Depois |
| --- | --- |
| `input * RUN_SPEED` | `input * RUN_SPEED * speed_scale` |
| `velocity.y += g * delta` | `velocity.y += g * gravity_scale * delta` |
| `minf(velocity.y, MAX_FALL)` | `minf(velocity.y, MAX_FALL * gravity_scale)` |

**Não** escalar `JUMP_VELOCITY` junto: com gravidade 1,15× e pulo igual, a
altura cai ~13 %, que é exatamente o que o modificador de gravidade quer.
Escalar os dois deixaria tudo igual e o modificador viraria enfeite.

`Level` repassa: `_player.speed_scale = player_speed_scale` etc., valores
que `main.gd` define a partir dos modificadores do run.

### 4.4 Id estável de sala

Faça isto **antes de qualquer passo que insira sala no meio da campanha.**

`levels.gd:all()` ganha uma chave nova por sala:

```gdscript
		{
			"id": "climb",              # estável, nunca reordenado
			"name": "level.6.name",
			...
		},
```

`save_manager.gd` passa a indexar por id:

```gdscript
func _key(index: int) -> String:
	return String(Levels.all()[index].get("id", str(index)))
```

e `best_time()`, `best_gems()`, `is_cleared()`, `record_clear()` usam `_key()`
em vez de `str(index)`. `DASH_ROOM`/`POUND_ROOM` viram ids:

```gdscript
const DASH_ROOM_ID := "first_dash"
const POUND_ROOM_ID := "slam"

func can_dash() -> bool:
	return is_unlocked(Levels.index_of(DASH_ROOM_ID))
```

**Migração:** no `_read()`, se o slot não tem `"schema": 2`, converter as
chaves numéricas para ids usando a ordem antiga (as 21 salas atuais, nessa
ordem) e gravar `"schema": 2`. Sem isso, todo jogador perde os tempos.

## 5. Para o agente

**Arquivos:** `player.gd`, `level.gd`, `levels.gd`, `save_manager.gd`, `main.gd`.

**Ordem:** 4.1 → 4.2 → 4.3 → 4.4. As três primeiras são independentes entre si.

**Armadilhas**
- `ground_tile()` amostra 2 px abaixo dos pés; com `floor_snap_length = 4.0` o
  player fica colado ao chão, então 2 px é seguro. Não usar 0.
- Não chamar `push()` de dentro de `_process()` de uma `Area2D`: a força tem
  que chegar antes do `_physics_process()` do player. Emissores usam
  `_physics_process()`.
- Escalar `MAX_FALL` sem escalar gravidade faz a queda demorar mais para
  saturar; escalar os dois juntos é o comportamento pretendido.
- A migração de save roda uma vez por slot. Testar com um `saves.json` antigo
  copiado à mão, não só com slot vazio.

**Critérios de aceite**
- Com `speed_scale = 1.0` e `gravity_scale = 1.0`, os 21 tempos de par
  continuam batendo — `tools/verify_rooms.py` passa sem mudança.
- `ground_tile()` devolve `"#"` em terreno normal e `"-"` em plataforma.
- `saves.json` de antes da mudança abre com tempos e gemas intactos.
