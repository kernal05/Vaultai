#!/usr/bin/env bash
# Run ONCE on the server before anything else.
# Creates the isolated network + directory structure for VaultAI.
# Does NOT touch any other project's network, volumes, or files.
set -euo pipefail

echo "== VaultAI bootstrap =="

# 1. Isolated network — separate from hms/verifychain/crm/frappe networks
if ! docker network inspect vaultai_net >/dev/null 2>&1; then
  docker network create vaultai_net
  echo "Created network: vaultai_net"
else
  echo "Network vaultai_net already exists, skipping"
fi

# 2. Confirm isolation — list what's attached (should be empty on first run)
echo "-- Containers currently on vaultai_net --"
docker network inspect vaultai_net -f '{{range .Containers}}{{.Name}} {{end}}'
echo ""

# 3. Directory layout under /opt/vaultai (NOT root's home dir, NOT shared paths)
BASE=/opt/vaultai
mkdir -p "$BASE"/{app,api,nginx,scripts,monitoring,backups}
echo "Directory layout ready at $BASE"

# 4. Resource sanity check before we deploy anything
echo ""
echo "-- Current host memory --"
free -h
echo ""
echo "-- Current host disk --"
df -h /

echo ""
echo "Bootstrap complete. Next: copy the vaultai/ project files into $BASE,"
echo "fill in .env from .env.example, then run scripts/01-deploy.sh"
