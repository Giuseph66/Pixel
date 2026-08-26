# PIXEL signal server

Go service for room discovery and WebRTC signalling. It stores rooms in memory,
authenticates temporary members, and forwards SDP/ICE messages between them.

The Godot client ships the official
[`webrtc-native` 1.2.1-stable](https://github.com/godotengine/webrtc-native/releases/tag/1.2.1-stable)
GDExtension. Its downloaded archive SHA-256 is
`f37d03da03da3ff0d092542a04586644f889135cb7a1c3566ad57513203a553b`.

It **does not** receive game packets. PIXEL gameplay travels directly between
players via WebRTC data channels. If direct P2P fails, coturn relays packets.
This removes port-forwarding and keeps the game serverless, but direct WebRTC
can expose a public candidate to the friend who joined the room.

## Seu comando (configuração atual)

Para subir o multiplayer nesta máquina, execute somente:

```sh
./server/pixel-server.sh local
```

Esse comando liga a sinalização e o TURN. O Cloudflare Tunnel já está instalado
como serviço do usuário e publica o jogo em
`https://pixel-signal.neurelix.com.br`.

Após reiniciar o computador, ele deve iniciar sozinho. Caso a URL pública não
responda, ligue-o manualmente:

```sh
systemctl --user start pixel-cloudflared.service
```

Verifique tudo com:

```sh
./server/pixel-server.sh status
curl https://pixel-signal.neurelix.com.br/healthz
```

Para desligar o servidor de jogo:

```sh
./server/pixel-server.sh stop
```

## Outra configuração

```sh
./server/pixel-server.sh setup
# edite server/.env
./server/pixel-server.sh start
```

`start` sobe sinalização, TURN e Cloudflare Tunnel via token Docker. Não use
esse comando na configuração atual: o serviço `pixel-cloudflared.service` já
cuida do túnel. Para testar só na máquina/LAN, use
`./server/pixel-server.sh local` e informe `http://127.0.0.1:8787` na tela
ONLINE do jogo.

Health check:

```sh
curl http://127.0.0.1:8787/healthz
```

## Docker

```sh
docker build -t pixel-signal server
docker run --rm -p 8787:8787 pixel-signal
```

For the complete public HTTPS + coturn deployment, follow
[DEPLOY.md](DEPLOY.md). Do not expose player tokens over plain HTTP on the
public internet.

## API

`POST /v1/rooms`

```json
{"name":"SALA DO LEO","password":"1234","capacity":4}
```

Returns room code plus host member token.

`POST /v1/rooms/{code}/join`

```json
{"name":"ANA","password":"1234"}
```

Returns member ID, stable Godot `peer_id`, and token. All remaining requests require:

```text
Authorization: Bearer <token>
```

Endpoints:

- `POST /v1/rooms/{code}/heartbeat`
- `GET /v1/rooms/{code}/info`
- `GET /v1/rooms/{code}/signals` — long-poll, max 20 seconds
- `POST /v1/rooms/{code}/signal` — `{"to":"peer_*","type":"offer|answer|candidate|bye","data":{...}}`
- `POST /v1/rooms/{code}/leave`

Rooms expire if a player misses heartbeats for 90 seconds. If the host expires
or leaves, the room closes.

`PIXEL_STUN_URLS`, `PIXEL_TURN_URLS` and `PIXEL_TURN_SECRET` make the service
return per-member ICE credentials. When TURN is not configured, local/direct
WebRTC can still work but NAT/CGNAT players may fail to connect.

Do not point `EnetTransport` at this service: Godot's high-level ENet protocol
is internal. WebRTC preserves `MultiplayerPeer` and the existing SessionManager
RPCs.
