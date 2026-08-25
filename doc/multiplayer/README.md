# Plano do multiplayer online

Status: MVP LAN implementado. O jogo já possui sessão autoritativa ENet,
lobby, handshake, senha, capacidade, sincronização básica e modos separados.
O código de sala pela internet continua dependente de um serviço de
sinalização/WebRTC/TURN publicado; o cliente deixa esse ponto explícito e não
finge que IP de LAN é um código online.

## Visão

Adicionar multiplayer online sem alterar o comportamento do single player atual.
Cada participante executa o jogo em sua própria máquina, enxerga a mesma sessão e
controla apenas o próprio personagem.

O host cria uma sala, escolhe capacidade, senha e modo de jogo. Os convidados
entram por um código curto. O host também joga e atua como servidor autoritativo.

Modos previstos:

- História.
- Infinito.
- Sandbox.
- Competitivo (corrida: o primeiro jogador na saída vence).

## Decisão principal

O gameplay usa um **listen server autoritativo**:

- O host simula a partida e valida os eventos.
- Os clientes enviam inputs.
- O host distribui snapshots e eventos confirmados.
- Não existe servidor dedicado de gameplay.

Para conexão simples pela internet, ainda existe uma infraestrutura pequena:

- Serviço de sinalização para criar e resolver códigos de sala.
- STUN para tentar conexão direta.
- TURN como fallback quando NAT/CGNAT impedir P2P.

Portanto, o gameplay pode ser P2P/sem servidor dedicado, mas a experiência de
"digitar um código e entrar" não é totalmente sem serviço externo.

## Princípios

- Single player continua funcionando com rede desligada.
- Um único modelo de física; sem duplicar regras de movimento.
- Host é a fonte da verdade.
- Transporte fica isolado da lógica de jogo.
- Código de sala não é senha.
- Capacidade é configurável pelo host, com limite técnico ajustável.
- Salas maiores no futuro não exigem reescrever o protocolo.
- Cada etapa precisa passar por um teste antes da próxima.

## Documentos

- [Arquitetura](./01-arquitetura.md)
- [Plano de implementação](./02-implementacao.md)
- [Protocolo e sincronização](./03-protocolo.md)
- [UI e regras dos modos](./04-ui-e-modos.md)
- [Testes e critérios de entrega](./05-testes.md)

## Execucao rapida LAN

Pelo menu: `MULTIPLAYER > CRIAR SALA LAN` em uma máquina e `ENTRAR POR IP` na
outra. A porta padrão é `27816`; em outra rede local, informe o IP privado do
host. Os dois jogadores precisam marcar `PRONTO` no lobby.

Também é possível iniciar um host para teste com argumentos:

```bash
godot --path . -- --net-role=host --net-port=27816 --net-capacity=4 --net-name=HOST
```

O cliente ainda deve usar a tela `ENTRAR POR IP`, porque a resolução de código
online só existe depois que o serviço de sinalização for configurado.

## Referências Godot

- [High-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html)
- [ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)
- [WebRTC no Godot 4.6](https://docs.godotengine.org/en/4.6/tutorials/networking/webrtc.html)
- [WebRTCMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_webrtcmultiplayerpeer.html)
- [UPnP](https://docs.godotengine.org/en/stable/classes/class_upnp.html)
- [MultiplayerSpawner](https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html)
- [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html)
