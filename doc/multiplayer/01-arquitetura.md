# Arquitetura

## Estado atual

O projeto atual é centrado em um jogador:

- `main.gd` controla menus, modo, construção da sala e resultados.
- `level.gd` mantém uma única referência `_player`.
- Inimigos, lava e porta recebem essa única referência.
- `player.gd` lê `Input` diretamente e executa física local.
- História e infinito escrevem progresso pelo `Save` local.
- O jogo inteiro cabe em uma tela fixa de 480x270.

O multiplayer precisa retirar esses acoplamentos sem criar uma segunda versão do
jogo. Offline deve continuar sendo o caso mais simples: uma sessão com um jogador
e sem transporte de rede.

## Componentes-alvo

```text
Menu/UI
  |
  v
SessionManager ---- Signaling API ---- Room registry/TTL
  |
  +---- NetworkTransport
  |       +---- ENet (LAN e desenvolvimento)
  |       +---- WebRTC (internet)
  |
  v
NetworkGame / Main
  |
  v
Level ---- Players[peer_id]
  |          |
  |          +---- Local input/prediction
  |          +---- Remote interpolation
  |
  +---- Host-owned world state
```

### `SessionManager`

Autoload responsável por:

- Estado offline, host ou cliente.
- Criação e encerramento da sessão.
- Lista de participantes.
- Configuração da sala.
- Handshake e compatibilidade.
- Sinais de conexão/desconexão.
- Troca do `MultiplayerPeer`.
- Heartbeat do código da sala.

Não deve conhecer física, inimigos ou regras específicas de fase.

### `SessionConfig`

Dados serializáveis da sala:

```text
protocol_version
game_version
content_hash
room_id
room_name
host_peer_id
mode_id
max_players
password_required
visibility
level_id
seed
allow_late_join
state
```

Estados da sessão:

```text
OFFLINE -> CONNECTING -> LOBBY -> LOADING -> PLAYING -> RESULTS -> LOBBY
                    \-> FAILED
```

### `NetworkTransport`

Interface conceitual:

```text
host(config)
join(invite)
close()
send_input(frame)
send_event(event)
connection_state()
```

A lógica do jogo não deve depender diretamente de ENet ou WebRTC.

## Transporte

### Desenvolvimento: ENet

Usar ENet primeiro para validar gameplay em loopback e LAN:

- Integrado ao Godot.
- UDP e baixa latência.
- Criação simples de host/cliente.
- Capacidade configurável em `create_server`.

Limitação: internet direta exige IP/porta e NAT traversal. UPnP ajuda, mas não
funciona em todo roteador e não resolve todos os casos de CGNAT.

### Internet: WebRTC

Usar WebRTC para a experiência final de código de sala:

- Tenta rota P2P direta.
- ICE/STUN para atravessar NAT.
- DTLS protege o transporte.
- TURN pode retransmitir quando conexão direta falhar.
- Exige troca de SDP e ICE por um serviço de sinalização.

No Godot nativo, WebRTC requer GDExtension externa. Essa dependência só deve ser
adicionada na etapa de internet, após o núcleo LAN estar estável.

### Serviço de sinalização

Não simula gameplay. Responsabilidades:

- Criar `room_id` aleatório.
- Gerar código curto legível.
- Guardar metadados temporários da sala.
- Encaminhar SDP/ICE durante negociação WebRTC.
- Aplicar TTL e remover salas abandonadas.
- Receber heartbeat do host.
- Bloquear novas entradas quando sala estiver cheia ou iniciada.

Registro mínimo da sala:

```text
room_id
code
host_session_token
current_players
max_players
password_required
game_version
created_at
expires_at
```

O código de sala deve ser aleatório, por exemplo `PX7K-29MD`. Não deve conter IP,
senha ou informação pessoal.

## Autoridade

| Estado | Autoridade |
|---|---|
| Inputs | Cliente dono envia; host valida |
| Posição/velocidade | Host |
| Dash, vida e animação | Host |
| Inimigos | Host |
| Gemas e segredos | Host |
| Blocos e plataformas | Host |
| Lava e hazards | Host |
| Porta e conclusão | Host |
| Seed/geração infinita | Host |
| Resultado | Host |
| Save local | Cada máquina, após resultado confirmado |

O peer do host é o ID `1`, conforme o modelo padrão da API multiplayer do Godot.
Nós de jogadores devem ter nomes estáveis derivados do `peer_id`, pois RPCs
exigem o mesmo `NodePath` entre peers.

## Modelo de jogador

`Level` deixa de possuir `_player` e passa a possuir:

```text
players: Dictionary[int, Player]
local_peer_id: int
```

Cada `Player` recebe um controlador:

- `LocalInputSource`: lê teclado/controle e gera `InputFrame`.
- `NetworkInputSource`: consome frames recebidos pelo host.
- `RemoteStateSource`: interpola snapshots em clientes.

Colisão entre jogadores fica desligada. Isso evita bloqueios, empurrões e
divergência física. Cada jogador recebe cor/contorno e nome próprios.

## Mundo autoritativo

Somente o host executa decisões do mundo:

- IA de inimigos.
- Coleta e destruição.
- Dano e morte.
- Movimento de plataformas.
- Temporizadores.
- Spawn e despawn.
- Conclusão de sala.

Clientes desenham o estado recebido. Efeitos puramente visuais podem rodar
localmente, desde que não alterem colisão ou resultado.

## Compatibilidade

O handshake rejeita:

- Versão de protocolo diferente.
- Versão do jogo incompatível.
- Conteúdo de fases diferente.
- Sala cheia.
- Senha inválida.
- Partida já iniciada quando late join estiver desligado.

`content_hash` deve representar dados que afetam gameplay: níveis, geração,
constantes físicas e tipos de entidade. Arte e idioma não precisam bloquear a
conexão se não alterarem colisão.

## Segurança

- Código da sala localiza a sessão; não concede confiança.
- Senha nunca entra no código da sala.
- Senha não deve ser armazenada em texto puro.
- Autenticação usa challenge-response com nonce e prova derivada da senha.
- Host valida tamanho, frequência e faixa de todo payload.
- Cliente não pode declarar gema, morte, conclusão ou posição final.
- RPC de cliente aceita apenas input, perfil público e estado de pronto.
- Limites por segundo evitam spam de handshake e input.
- Nome de jogador precisa de limite e caracteres filtrados.

## Capacidade

O host escolhe `max_players`. O valor não deve estar espalhado no código.

Configuração inicial recomendada:

- UI: 2 a 16.
- Constante técnica ajustável: 32.
- Testes obrigatórios: 2, 4, 8 e 16.

Depois de medir CPU, banda e legibilidade visual, o teto pode subir. A API pode
aceitar números maiores, mas a sala atual e a máquina do host são limites reais.

## Decisões fora do MVP

- Migração automática de host.
- Matchmaking público global.
- Conta central.
- Chat de voz.
- Espectador com rewind.
- Anti-cheat forte.
- Servidor dedicado.

No MVP, se o host sair, a sessão termina e todos voltam ao menu multiplayer.

