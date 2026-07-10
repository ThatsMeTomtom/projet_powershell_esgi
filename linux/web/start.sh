#!/bin/bash

# Linux Web Stack Automation Script
# Pull latest code and start/restart the public + intranet websites

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  echo "[*] Docker or Docker Compose not found. Installing prerequisites..."
  "$SCRIPT_DIR/../install-docker.sh"
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "[!] Docker Compose is still unavailable." >&2
  exit 1
fi

# Fresh Docker installs require a re-login before the docker group applies.
# Fall back to sudo transparently so a single run always works.
if docker info >/dev/null 2>&1; then
  DOCKER_SUDO=()
elif command -v sudo >/dev/null 2>&1; then
  DOCKER_SUDO=(sudo)
else
  echo "[!] Cannot reach the Docker daemon and sudo is unavailable." >&2
  exit 1
fi

echo "========================================="
echo "Linux Web Stack - Auto Startup"
echo "========================================="

echo "[*] Pulling latest from git..."
cd "$PROJECT_ROOT"
git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "[!] Git pull skipped"

cd "$SCRIPT_DIR"

echo "[*] Stopping previous web containers..."
"${DOCKER_SUDO[@]}" "${COMPOSE_CMD[@]}" down 2>/dev/null || true

echo "[*] Starting web stack..."
"${DOCKER_SUDO[@]}" "${COMPOSE_CMD[@]}" up -d

echo "[*] Verifying container status..."
"${DOCKER_SUDO[@]}" "${COMPOSE_CMD[@]}" ps

echo ""
echo "========================================="
echo "✓ Web stack is running"
echo "========================================="
echo ""
echo "View logs: ${DOCKER_SUDO[*]} ${COMPOSE_CMD[*]} -f $SCRIPT_DIR/docker-compose.yml logs -f"
echo "Stop:      ${DOCKER_SUDO[*]} ${COMPOSE_CMD[*]} -f $SCRIPT_DIR/docker-compose.yml down"
