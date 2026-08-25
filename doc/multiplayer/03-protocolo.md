# Protocolo e sincronização

## Objetivos

- Movimento responsivo.
- Host autoritativo.
- Eventos críticos sem duplicação.
- Tráfego pequeno.
- Compatibilidade verificável.
- Transporte substituível.

## Relógio

- Física local: tick fixo do Godot.
- Cada `InputFrame` recebe `tick` e `sequence`.
- Host mantém `server_tick` monotônico.
- Snapshots iniciais: 20 por segundo.
- Inputs: um por tick, agrupando frames recentes para tolerar perda.
- Eventos críticos: imediatos e confiáveis.

Valores serão ajustados por medição, não por sensação isolada.

## Canais

| Canal | Modo | Uso |
|---|---|---|
| 0 | Reliable | Handshake, lobby, eventos, transições |
| 1 | Unreliable ordered | Inputs |
| 2 | Unreliable ordered | Snapshots |
| 3 | Reliable | Snapshot completo e recuperação |

Movimento atrasado não deve ser retransmitido: um snapshot novo substitui o velho.
Coleta, morte e mudança de sala precisam chegar e manter ordem.

## Handshake

Cliente envia:

```text
protocol_version
game_version
content_hash
room_id
nickname
client_nonce
password_proof
```

Host responde:

```text
accepted
reason
peer_id
session_token
session_config
server_tick
```

Motivos de rejeição estáveis:

```text
ROOM_NOT_FOUND
ROOM_FULL
ROOM_STARTED
BAD_PASSWORD
VERSION_MISMATCH
CONTENT_MISMATCH
BANNED
TIMEOUT
INTERNAL_ERROR
```

## Código e senha

- Código identifica `room_id` no serviço de sinalização.
- Código usa alfabeto sem caracteres ambíguos.
- Senha permanece separada.
- Serviço guarda apenas o necessário para negociar conexão.
- Host envia nonce; cliente responde com prova derivada da senha e nonce.
- Nonce não pode ser reutilizado.
- Após autenticação, cliente recebe token temporário da sessão.

## Input

Representação conceitual:

```text
InputFrame {
  peer_id
  tick
  sequence
  buttons_bitmask
  axis_x
  axis_y
}
```

Bits possíveis:

```text
LEFT
RIGHT
UP
DOWN
JUMP
DASH
POUND
PAUSE_REQUEST
```

Host valida:

- `peer_id` pertence ao remetente.
- Tick está dentro da janela permitida.
- Sequência não voltou.
- Eixos estão normalizados.
- Frequência não excede limite.
- Input não é aceito fora de `PLAYING`.

## Snapshot de jogador

```text
PlayerSnapshot {
  peer_id
  server_tick
  acknowledged_input_sequence
  position
  velocity
  facing
  alive
  frozen
  has_dash
  dash_state
  pound_state
  animation_id
}
```

Não sincronizar textura, tween ou partículas. Cada cliente reconstrói visualmente.

## Previsão e reconciliação

Jogador local:

1. Lê input.
2. Guarda frame em buffer.
3. Simula imediatamente.
4. Envia ao host.
5. Recebe snapshot com último input confirmado.
6. Corrige para estado do host.
7. Reaplica inputs ainda não confirmados.

Correções pequenas são suavizadas. Erros grandes, morte e teleporte aplicam snap
imediato.

Jogadores remotos:

- Mantêm pequeno buffer de snapshots.
- Renderizam entre dois estados confirmados.
- Extrapolação curta somente quando faltar um snapshot.
- Nunca executam decisões autoritativas.

## Eventos do mundo

Estrutura:

```text
WorldEvent {
  event_id
  server_tick
  type
  entity_id
  payload
}
```

Tipos iniciais:

```text
PLAYER_SPAWN
PLAYER_DIED
PLAYER_RESPAWN
GEM_TAKEN
SECRET_TAKEN
ENEMY_DIED
BLOCK_BROKEN
CRUMBLE_STARTED
PLATFORM_STATE
LAVA_STATE
DOOR_CHARGE
PLAYER_ENTERED_DOOR
ROOM_COMPLETED
ROOM_RESTARTED
```

Cada cliente guarda uma janela de `event_id` processados. Evento repetido é
ignorado.

## Identidade de entidades

IDs precisam ser iguais em todas as máquinas:

- Jogador: `player:<peer_id>`.
- Entidade estática: índice da sala + tile + tipo.
- Entidade gerada: seed + contador autoritativo.
- Sala sandbox: hash do conteúdo + tile + tipo.

Não usar `instance_id`, pois ele muda entre processos.

## Spawn e NodePath

- Nós replicados recebem nomes explícitos.
- Host cria e remove.
- Clientes não chamam `add_child` para entidades autoritativas por conta própria.
- `MultiplayerSpawner` pode replicar jogadores e entidades dinâmicas.
- `MultiplayerSynchronizer` pode servir para estado simples.
- Movimento de plataforma rápida/jogador usa snapshots manuais para controle fino.

## Estado completo

Enviado ao terminar loading, reconectar ou detectar divergência:

```text
FullRoomState {
  session_config
  server_tick
  level_id/level_data
  players[]
  entities[]
  collected_gems[]
  destroyed_blocks[]
  timers[]
  door_state
  mode_state
}
```

Aplicação deve ser atômica: cliente pausa simulação, aplica tudo e confirma.

## Mudança de sala

1. Host envia `PREPARE_ROOM` com ID/seed/hash.
2. Clientes carregam dados e respondem `ROOM_READY`.
3. Host aguarda todos ou timeout.
4. Host envia `START_ROOM(server_tick)`.
5. Todos iniciam no tick combinado.
6. Entradas ficam bloqueadas até `PLAYING`.

## Pause

Um cliente não pausa a sessão inteira. `PAUSE_REQUEST` abre menu apenas local e
mantém personagem parado segundo regra do modo. Somente host pode pausar a sessão
global, se essa opção existir.

## Desconexão

Cliente saiu:

- Host remove jogador.
- Porta e regra de conclusão recalculam participantes ativos.
- Lobby atualiza capacidade.
- Save do cliente não é alterado após desconexão incompleta.

Host saiu:

- MVP: sessão termina.
- Clientes recebem `HOST_LEFT` quando possível e voltam ao menu.
- Migração de host fica para versão posterior.

