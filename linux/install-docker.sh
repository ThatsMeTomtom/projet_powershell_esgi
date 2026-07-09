#!/bin/bash

# Installs Docker Engine following the official Docker documentation:
# https://docs.docker.com/engine/install/debian/

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
echo "Docker Engine Bootstrap (official Docker apt repo)"
echo "========================================="

echo "[*] Removing conflicting packages, if any..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  apt-get remove -y "$pkg" >/dev/null 2>&1 || true
done

echo "[*] Updating package index..."
apt-get update

echo "[*] Installing prerequisites..."
apt-get install -y ca-certificates curl

echo "[*] Adding Docker's official GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"

write_docker_source() {
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $1 stable" \
    > /etc/apt/sources.list.d/docker.list
}

echo "[*] Adding Docker's official apt repository (Debian $CODENAME)..."
write_docker_source "$CODENAME"

if ! apt-get update; then
  echo "[!] Debian '$CODENAME' is not published on Docker's apt repo yet. Falling back to 'bookworm'..."
  CODENAME="bookworm"
  write_docker_source "$CODENAME"
  apt-get update
fi

echo "[*] Installing Docker Engine and Compose plugin..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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
echo "  bash $SCRIPT_DIR/deploy.sh"
