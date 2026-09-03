#!/usr/bin/env bash
# Run this on YOUR LAPTOP (not the server) to reach VaultAI.
# Forwards all VaultAI ports from the server's localhost to your laptop's localhost.
set -euo pipefail

SERVER="root@103.192.198.240"

echo "Opening SSH tunnel to VaultAI on $SERVER ..."
echo "Once connected, open on YOUR machine:"
echo "  Frontend:   http://localhost:8081"
echo "  API:        http://localhost:8082/healthz"
echo "  Prometheus: http://localhost:9091"
echo "  Grafana:    http://localhost:3001"
echo ""
echo "Press Ctrl+C to close the tunnel."

ssh -N \
  -L 8081:127.0.0.1:8081 \
  -L 8082:127.0.0.1:8082 \
  -L 9091:127.0.0.1:9091 \
  -L 3001:127.0.0.1:3001 \
  "$SERVER"
