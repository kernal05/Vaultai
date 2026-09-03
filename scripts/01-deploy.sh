#!/usr/bin/env bash
# Deploy or update the VaultAI stack. Safe to re-run (idempotent).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== VaultAI deploy =="

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Copy .env.example to .env and fill in secrets first."
  exit 1
fi

# Pre-flight: refuse to deploy if host is critically low on memory.
AVAILABLE_MB=$(free -m | awk '/^Mem:/{print $7}')
if [ "$AVAILABLE_MB" -lt 800 ]; then
  echo "ERROR: only ${AVAILABLE_MB}MB available on host. Aborting deploy to avoid OOM"
  echo "        pressure on other projects sharing this box."
  exit 1
fi
echo "Pre-flight OK: ${AVAILABLE_MB}MB available"

# Lock secrets file down — readable only by the owning user (vaultai)
chmod 600 .env

docker compose --env-file .env pull --ignore-pull-failures || true
docker compose --env-file .env build
docker compose --env-file .env up -d

echo ""
echo "-- Status --"
docker compose ps

echo ""
echo "-- VaultAI resource footprint (should stay within budget) --"
docker stats --no-stream $(docker compose ps -q)
