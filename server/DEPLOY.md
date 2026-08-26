# Public deployment

This stack gives PIXEL a room-code signalling service plus a self-hosted TURN
relay. It is sufficient for friends behind NAT or CGNAT. Gameplay stays
player-to-player whenever possible; TURN only relays a failed direct route.

## 1. Local machine + Cloudflare Tunnel

This is the intended development setup. It runs the Go signal service and
coturn on this machine; Cloudflare Tunnel gives only the signal service a
public HTTPS URL.

Create these DNS/public-hostname entries, assuming the domain is
`neurelix.com.br`:

- `pixel-signal.neurelix.com.br` — **Proxied**. In Cloudflare Zero Trust, create a
  Tunnel and a Public Hostname pointing to `http://signal:8787`.
- `turn.pixel.neurelix.com.br` — **DNS only** (grey cloud), `A` record to this
  machine's public WAN IPv4. Cloudflare proxy/Tunnel cannot carry TURN UDP.

Copy `.env.example` to `.env`, set the real WAN IPv4 and Tunnel token, then:

```sh
./server/pixel-server.sh setup
# edit server/.env
./server/pixel-server.sh start
```

Forward these router ports to the local machine: TCP/UDP `3478` and UDP
`49160-49200`. Without those TURN ports, same-network/direct WebRTC can work,
but friends behind restrictive NAT/CGNAT are not guaranteed to connect.

Cloudflare automatically serves TLS for `pixel-signal.neurelix.com.br`; do not run
the Caddy profile at the same time as the Tunnel profile.

## 2. VPS alternative

Use a small Linux VPS with a public IPv4, Docker Compose, and these firewall
rules:

- TCP `80`, `443` — HTTPS signalling / TLS certificate;
- UDP and TCP `3478` — TURN/STUN;
- UDP `49160-49200` — TURN relay range.

Copy `.env.example` to `.env`, replace every sample value, then start:

```sh
cd server
docker compose --profile tls up -d --build
```

`PIXEL_SIGNAL_DOMAIN` needs a DNS `A` record before Caddy can issue HTTPS.
Check both services:

```sh
curl https://pixel-signal.neurelix.com.br/healthz
docker compose logs -f signal turn
```

## 3. Game

Set the same public URL in the Online multiplayer form, for example:

```text
https://pixel-signal.neurelix.com.br
```

For development on one machine use `http://127.0.0.1:8787`; start the signal
service with `docker compose up signal` or `go run ./cmd/pixel-signal`.

The game reads `PIXEL_SIGNAL_URL` first. That lets CI/dev exports use a local
endpoint without changing source. For a release, set the project setting
`network/multiplayer/signal_url` to the public HTTPS URL.

## Operations

- Never commit `.env` or the TURN secret.
- Rotate `TURN_SHARED_SECRET` when access changes; existing rooms are short
  lived and will reconnect with fresh credentials.
- Room and member data live only in memory. Restarting the signal container
  closes current rooms but does not affect saves.
- TURN credentials expire after 24 hours and are issued only after a room
  password is accepted.
