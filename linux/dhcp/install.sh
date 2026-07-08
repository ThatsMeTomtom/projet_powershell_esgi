#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    echo "[*] Re-running with sudo..."
    exec sudo "$0" "$@"
  fi
  echo "[!] This script must be run as root or with sudo." >&2
  exit 1
fi

echo "========================================="
echo "Debian 13 Docker Bootstrap"
echo "========================================="

echo "[*] Updating package index..."
apt-get update

echo "[*] Installing prerequisites..."
apt-get install -y ca-certificates curl gnupg lsb-release git apt-transport-https

echo "[*] Installing Docker Engine and Compose plugin..."
apt-get install -y docker.io docker-compose-plugin

echo "[*] Enabling and starting Docker service..."
systemctl enable docker
systemctl start docker

if id -nG "$(logname 2>/dev/null || echo root)" | grep -qw docker; then
  :
else
  echo "[*] Adding current user to docker group..."
  usermod -aG docker "$(logname 2>/dev/null || echo root)"
fi

echo "[*] Verifying Docker installation..."
docker --version
docker compose version

echo ""
echo "========================================="
echo "✓ Docker is ready"
echo "========================================="
echo ""
echo "Next step:"
echo "  cd $SCRIPT_DIR"
echo "  bash start.sh"
