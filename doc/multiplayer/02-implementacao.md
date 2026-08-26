# Plano de implementação

Cada etapa termina com validação. Não avançar acumulando falhas conhecidas.

## Etapa 0 — congelar comportamento offline (base existente)

Objetivo: criar referência para impedir regressões.

Tarefas:

- Registrar fluxo atual de História, Infinito e Sandbox.
- Registrar movimento: corrida, pulo, parede, dash e pound.
- Registrar interação com cada hazard.
- Confirmar parser do projeto limpo.
- Documentar saves usados nos testes.

Aceite:

- Single player abre, joga, morre, reinicia e conclui sala.
- História e infinito continuam salvando corretamente.

## Etapa 1 — núcleo de sessão offline/LAN (implementada)

Criar:

```text
scripts/network/session_manager.gd
scripts/network/session_config.gd
scripts/network/network_transport.gd
scripts/network/enet_transport.gd
scripts/network/network_log.gd
```

Alterar:

```text
project.godot                  # autoload Session
scripts/main.gd               # respeitar Session.offline
```

Tarefas:

- Implementar estados da sessão.
- Implementar `host_lan(port, max_players)`.
- Implementar `join_lan(address, port)`.
- Conectar sinais `peer_connected`, `peer_disconnected`, falha e timeout.
- Criar handshake de protocolo e versão.
- Garantir `close()` idempotente.
- Manter multiplayer peer offline quando JOGAR normal for escolhido.

Aceite:

- Duas instâncias conectam por `127.0.0.1`.
- Duas máquinas conectam pela LAN.
- Single player continua sem criar socket.
- Desconexão retorna estado coerente.

## Etapa 2 — UI de criar, entrar e lobby (implementada para LAN)

Criar:

```text
scripts/multiplayer/multiplayer_screen.gd
scripts/multiplayer/host_screen.gd
scripts/multiplayer/join_screen.gd
scripts/multiplayer/lobby_screen.gd
```

Alterar:

```text
scripts/title_screen.gd
scripts/main.gd
scripts/i18n.gd
scripts/pixel_art.gd             # apenas ícones necessários
```

Tarefas:

- Adicionar MULTIPLAYER sem alterar ação de JOGAR.
- Criar formulário do host.
- Criar formulário de entrada LAN temporário.
- Criar lista de participantes e estado pronto.
- Permitir host alterar modo e capacidade.
- Permitir host expulsar participante.
- Bloquear início enquanto alguém não confirmou carregamento/pronto.
- Exibir erros traduzidos.

Aceite:

- Host cria lobby.
- Cliente entra e aparece para todos.
- Sala cheia rejeita nova entrada.
- Host consegue iniciar e encerrar lobby.

## Etapa 3 — múltiplos jogadores na mesma sala (implementada no MVP)

Criar:

```text
scripts/network/input_frame.gd
scripts/network/player_snapshot.gd
scripts/network/network_player_controller.gd
```

Alterar principalmente:

```text
scripts/player.gd
scripts/level.gd
scripts/main.gd
scripts/hud.gd
```

Tarefas:

- Separar leitura de input da simulação do `Player`.
- Substituir `_player` por `players[peer_id]` no `Level`.
- Spawnar um jogador por participante.
- Nomear nós pelo `peer_id`.
- Marcar autoridade corretamente.
- Desligar colisão jogador-jogador.
- Adicionar identificação visual.
- Enviar inputs ao host.
- Enviar snapshots aos clientes.
- Interpolar jogadores remotos.
- Adicionar previsão/reconciliação do jogador local.

Aceite:

- Dois jogadores movem personagens distintos.
- Cada máquina controla apenas seu personagem.
- Host e cliente enxergam posições equivalentes.
- Dash, parede e pound mantêm sensação do offline.

## Etapa 4 — sincronizar mundo (núcleo implementado)

Alterar entidades gradualmente:

```text
scripts/level.gd
scripts/slime.gd
scripts/elastic_slime.gd
scripts/shield_enemy.gd
scripts/bat.gd
scripts/lava.gd
scripts/gem.gd
scripts/exit_door.gd
scripts/moving_platform.gd
scripts/timed_block.gd
scripts/crumble.gd
scripts/breakable.gd
```

Ordem:

1. Gemas e porta.
2. Morte e respawn.
3. Plataformas e blocos.
4. Inimigos.
5. Lava e hazards temporizados.

Tarefas:

- Host executa lógica autoritativa.
- Eventos recebem `event_id` único.
- Clientes ignoram eventos repetidos.
- Spawn/despawn usa caminhos estáveis.
- Estado completo pode ser reenviado após perda/reconexão.
- IA escolhe alvo válido entre jogadores vivos.

Aceite:

- Uma gema só pode ser coletada uma vez.
- Todos veem o mesmo inimigo e bloco.
- Mortes não duplicam.
- Porta conclui uma única vez.

## Etapa 5 — fluxo dos modos (história, infinito, corrida e sandbox implementados)

Criar uma camada de regras, por exemplo:

```text
scripts/modes/game_mode.gd
scripts/modes/story_multiplayer_mode.gd
scripts/modes/endless_multiplayer_mode.gd
scripts/modes/sandbox_multiplayer_mode.gd
```

História:

- Host escolhe sala permitida.
- Gemas compartilhadas.
- Todos os jogadores ativos precisam chegar à saída.
- Resultado confirmado é registrado localmente por cada participante.

Infinito:

- Host gera e distribui seed/depth.
- Todos carregam a mesma sala.
- Party wipe encerra a run.

Sandbox:

- Host envia definição serializada da sala.
- Cliente valida dimensões, tiles e limites antes de carregar.
- Sala recebida não é gravada automaticamente na biblioteca local.

Competitivo:

- Apenas contrato `mode_id` nesta etapa.
- Regras e pontuação entram depois sem mudar transporte.

Aceite:

- Lobby inicia cada modo existente.
- Mudança de sala ocorre em conjunto.
- Todos retornam ao mesmo lobby/resultados.
- Save offline não é contaminado por sessão incompleta.

## Etapa 6 — código de sala e internet (implementada; deploy necessário)

Backend/sinalização:

- Criar sala com TTL.
- Gerar código curto.
- Resolver código.
- Heartbeat do host.
- Trocar SDP e ICE.
- Encerrar e expirar sala.

Cliente Godot:

```text
scripts/network/signaling_client.gd
scripts/network/webrtc_transport.gd
```

Implementado:

- `addons/webrtc_native`: GDExtension oficial WebRTC Native 1.2.1.
- `server/`: sinalização Go com código, senha, TTL, tokens e SDP/ICE.
- `server/compose.yaml`: coturn com credenciais temporárias e Caddy HTTPS.
- Formulários ONLINE por código, mantendo LAN como diagnóstico.
- Dados de jogo seguem pelo `WebRTCMultiplayerPeer`; o sinalizador não carrega
  gameplay.

Aceite:

- Duas máquinas em redes diferentes conectam por código.
- Senha opcional funciona.
- Sala expira quando host desaparece.
- Falha de P2P tenta relay e produz erro claro se relay indisponível.

Operação: preencher `server/.env` a partir de `.env.example`, publicar o
domínio e configurar o cliente com a URL HTTPS. Ver `server/DEPLOY.md`.

## Etapa 7 — segurança e robustez

Tarefas:

- Challenge-response da senha.
- Tokens temporários por participante.
- Rate limit de entrada e RPC.
- Limites de string e payload.
- Rejeição de mensagem fora do estado esperado.
- Timeout de carregamento.
- Snapshot completo para recuperação.
- Tratamento de host/client quit e perda de internet.
- Logs sem senha/token.

Aceite:

- Pacote inválido não derruba host.
- Senha não aparece em log.
- Cliente incompatível recebe motivo legível.
- Host saindo encerra sessão de forma limpa.

## Etapa 8 — capacidade e otimização

Tarefas:

- Medir bytes por jogador por segundo.
- Medir física do host com 2, 4, 8 e 16 jogadores.
- Ajustar taxa de snapshot.
- Comprimir bitmask de input.
- Dormir entidades distantes quando houver salas maiores.
- Adicionar limite visual de nomes/efeitos.

Aceite:

- Host mantém física estável no teto publicado.
- Cliente não acumula snapshots atrasados.
- Entrada acima da capacidade é rejeitada antes do gameplay.

## Etapa 9 — salas maiores

Só iniciar após multiplayer atual estar estável.

Preparação já necessária:

- Sincronizar coordenadas do mundo, não coordenadas da tela.
- Não assumir que todos os jogadores estão visíveis.
- Separar câmera local do estado autoritativo.
- Preparar filtros de relevância por região.

Implementação futura:

- Câmera segue jogador local.
- Limites maiores de grid.
- Spawn/checkpoints por região.
- Sincronização por interesse/visibilidade.

## Ordem recomendada de commits

1. `feat: add offline session foundation`
2. `feat: add ENet LAN lobby`
3. `refactor: separate player input from physics`
4. `feat: spawn network players`
5. `feat: sync level events`
6. `feat: run story sessions online`
7. `feat: run endless and sandbox online`
8. `feat: add room-code signaling`
9. `feat: add WebRTC internet transport`
10. `fix: harden reconnect and invalid packets`
