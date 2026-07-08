#!/bin/bash

# Linux DHCP Server Automation Script
# Pull latest code and start/restart DHCP server

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  echo "[*] Docker or Docker Compose not found. Installing prerequisites..."
  "$SCRIPT_DIR/install.sh"
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "[!] Docker Compose is still unavailable." >&2
  exit 1
fi

echo "========================================="
echo "Linux DHCP Server - Auto Startup"
echo "========================================="

echo "[*] Pulling latest from git..."
cd "$PROJECT_ROOT"
git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || echo "[!] Git pull skipped"

cd "$SCRIPT_DIR"

echo "[*] Stopping previous DHCP container..."
"${COMPOSE_CMD[@]}" down 2>/dev/null || true

echo "[*] Starting DHCP server..."
"${COMPOSE_CMD[@]}" up -d

echo "[*] Verifying container status..."
"${COMPOSE_CMD[@]}" ps

echo ""
echo "========================================="
echo "✓ DHCP Server is running"
echo "========================================="
echo ""
echo "View logs: ${COMPOSE_CMD[*]} -f $SCRIPT_DIR/docker-compose.yml logs -f"
echo "Stop:      ${COMPOSE_CMD[*]} -f $SCRIPT_DIR/docker-compose.yml down"
