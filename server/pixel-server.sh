#!/usr/bin/env bash
set -Eeuo pipefail

# PIXEL local server runner. Run this file from anywhere.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

usage() {
	cat <<'EOF'
PIXEL multiplayer server

Usage:
  ./pixel-server.sh start   Start signal + TURN + Cloudflare Tunnel (default)
  ./pixel-server.sh local   Start signal + TURN only, for local/LAN testing
  ./pixel-server.sh setup   Create server/.env from the template
  ./pixel-server.sh status  Show service state
  ./pixel-server.sh logs    Follow service logs
  ./pixel-server.sh stop    Stop all PIXEL services

First run:
  ./pixel-server.sh setup
  Edit server/.env with the Tunnel token, public IP and TURN secret.
  ./pixel-server.sh start
EOF
}

need_docker() {
	if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
		echo "Docker Compose nao encontrado. Instale Docker Desktop/Engine primeiro."
		exit 1
	fi
}

setup_env() {
	if [[ -f "$ENV_FILE" ]]; then
		echo "Arquivo ja existe: $ENV_FILE"
		return
	fi
	cp "$ENV_EXAMPLE" "$ENV_FILE"
	echo "Criado: $ENV_FILE"
	echo "Edite TURN_EXTERNAL_IP, TURN_SHARED_SECRET e CLOUDFLARE_TUNNEL_TOKEN."
}

require_configured_env() {
	if [[ ! -f "$ENV_FILE" ]]; then
		setup_env
		echo "Configure o .env antes de iniciar."
		exit 1
	fi
	if grep -qE '^(TURN_EXTERNAL_IP=203\.0\.113\.10|TURN_SHARED_SECRET=replace-|CLOUDFLARE_TUNNEL_TOKEN=replace-)' "$ENV_FILE"; then
		echo "O .env ainda possui valores de exemplo. Corrija-o antes de iniciar."
		exit 1
	fi
}

compose() {
	docker compose --env-file "$ENV_FILE" -f "$SCRIPT_DIR/compose.yaml" "$@"
}

start_cloudflare() {
	need_docker
	require_configured_env
	compose --profile cloudflare up -d --build
	echo "Servidor iniciado. URL: https://pixel-signal.neurelix.com.br"
	echo "TURN exige DNS-only + redirecionamento TCP/UDP 3478 e UDP 49160-49200."
}

start_local() {
	need_docker
	if [[ ! -f "$ENV_FILE" ]]; then
		setup_env
	fi
	compose up -d --build signal turn
	echo "Servidor local iniciado: http://127.0.0.1:8787"
}

command="${1:-start}"
case "$command" in
	start)
		start_cloudflare
		;;
	local)
		start_local
		;;
	setup)
		setup_env
		;;
	status)
		need_docker
		compose ps
		;;
	logs)
		need_docker
		compose logs -f --tail=100
		;;
	stop)
		need_docker
		compose down
		;;
	-h|--help|help)
		usage
		;;
	*)
		echo "Comando desconhecido: $command"
		usage
		exit 2
		;;
esac
