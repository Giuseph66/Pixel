# BOMBADO — passo a passo de implementacao

Ordem real dos commits/edicoes. Cada passo compila sozinho.

## 1. Tecla

`scripts/main.gd::_setup_input()`

```
_action("p_buff", [KEY_F], [JOY_BUTTON_RIGHT_STICK])
```

Com um comentario dizendo que so e lida em sala de sandbox, no mesmo estilo
das notas que `p_codex` e `p_echo` ja carregam.

## 2. Gate por modo

- `scripts/level.gd`: `var buff_unlocked := false` (padrao **falso** — o
  contrario de `dash_unlocked`, que e `true`, porque este poder e a excecao e
  nao a regra).
- `scripts/level.gd::_spawn_player()`: `player.buff_unlocked = buff_unlocked`.
- `scripts/main.gd::_build_room()`: `_level.buff_unlocked = _sandbox`.

## 3. Arte

`scripts/pixel_art.gd`: 13 grades novas de 26x30 em `GRIDS`, agrupadas sob um
comentario de bloco. A cabeca de `player_idle` entra inteira em cada uma.

`scripts/palette.gd`: `CYAN_DEEP` novo e `"S"` em `CHARS`.

`scripts/player.gd::_player_texture()`: mapeia `"S"` para
`primary.darkened(0.72)`, junto dos tres tons que ja existiam.

Ver [02-arte.md](./02-arte.md) para o porque do quarto tom.

`scripts/player.gd::_player_animation()`: aceitar `buff_` alem de `player_`,
para o boneco remoto conseguir desenhar a forma.

## 4. Som

`scripts/sfx.gd::library()`: `buff_rise`, `buff_ready`, `buff_pose`,
`buff_sink`.

## 5. Corpo de tamanho variavel

`scripts/player.gd`:

- constantes `BUFF_WIDTH := 14.0`, `BUFF_HEIGHT := 24.0`,
  `BUFF_SPRITE_HEIGHT := 30.0`;
- `body_width()` / `body_height()` respondem pelo estado atual
  (bombado > footless > normal);
- `_apply_body_height()` vira `_apply_body_size()` e passa a mexer tambem na
  largura, mantendo a regra que ja existe: encolhe/cresce pela cabeca, a borda
  de baixo nao sai do lugar.
- `_has_headroom()` passa a receber largura e altura alvo em vez de assumir
  `WIDTH`/`HEIGHT`, e vira a checagem de espaco tambem do bombado.

Cuidado: `previous_bottom`, `_fx_at()`, `_land_pound()`, `_has_headroom()` e
`kill()` usam `HEIGHT` cru hoje. Todos passam a usar `body_height()`.

## 6. Maquina de estados

`scripts/player.gd`, bloco novo `# ---- bombado ----`:

- `_buff` (fase), `_buff_t` (relogio da fase), `_pose`, `_pose_t`,
  `_pose_index`;
- `_try_buff(controls)` — todas as condicoes de [01-estados.md](./01-estados.md);
- `_enter_buff()` / `_tick_buff_rise(delta)` / `_tick_buff_sink(delta)` /
  `_leave_buff(instant)`;
- `_tick_poses(delta)`;
- `is_buff()` publico, para `Level` e para os testes.

`_physics_process()` ganha dois desvios antes de tudo:

```
if _buff == BUFF_RISE or _buff == BUFF_SINK:
    _tick_buff_cutscene(delta)
    return
```

e, no ramo normal, `_try_buff(controls)` logo depois de `_try_pound()`.

Multiplicadores: `_apply_horizontal`, `_apply_gravity`, `_handle_jump`,
`_try_pound`, `_tick_pound`, `_land_pound` leem os fatores de um punhado de
helpers (`_speed_mul()`, `_gravity_mul()`, `_jump_mul()`) em vez de espalhar
`if _buff` por dentro da fisica.

## 7. Nascimento

Em `BUFF_RISE`, `_update_sprite()` e substituido por `_draw_rising()`:

- textura `buff_rise`;
- `sprite.region_enabled = true` e `region_rect` revelando de cima para baixo
  conforme `_buff_t` avanca (`t = _buff_t / BUFF_RISE_TIME`);
- `sprite.offset` vem de `_sprite_offset_for(fatia)`, de modo que a borda de
  baixo da parte visivel fica **parada** na linha do chao enquanto a fatia
  cresce para cima — o efeito e o corpo passando a existir acima da terra, nao
  um sprite deslizando por cima dela;
- `fx.emit()` de terra (`Palette.FRAME` e `Palette.BG_SOFT`) para cima nos pes,
  a cada quadro;
- `level.shake()` crescente via o sinal `visual_event`, que o `Level` ja
  escuta.

`region_rect` e o truque que dispensa shader/mascara: o Godot so desenha a
fatia pedida da textura.

## 8. Clima

- `scripts/buff_aura.gd` novo — ver [03-clima.md](./03-clima.md).
- `scripts/level.gd`: cria a aura sob demanda quando o jogador local fica
  bombado, e manda ela desligar quando sai; tremor de fundo no
  `_process()`.

## 9. Limpeza

`Player.kill()`, `Player.respawn()` e `Level.restart()` chamam
`_leave_buff(true)` — sem cutscene, sem aura, corpo de volta ao normal.

## 10. Texto

`scripts/i18n.gd`: `buff.name` = `BOMBADO` / `BOMBADO` / `BESTIA`, nas tres
linguas. Usado no popup do nascimento. **Nao** entra no codex.

## 11. Teste

`tools/check_sandbox.gd`: `_check_buff()`. Ver [05-testes.md](./05-testes.md).
