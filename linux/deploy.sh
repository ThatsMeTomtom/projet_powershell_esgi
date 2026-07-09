#!/bin/bash

# One-click deployment: DHCP server + Web stack (public + intranet)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "########################################"
echo "# Deploying DHCP server"
echo "########################################"
bash "$SCRIPT_DIR/dhcp/start.sh"

echo ""
echo "########################################"
echo "# Deploying Web stack"
echo "########################################"
bash "$SCRIPT_DIR/web/start.sh"

echo ""
echo "########################################"
echo "# ✓ Deployment complete"
echo "########################################"
