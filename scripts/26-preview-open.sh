#!/usr/bin/env bash
# ./scripts/26-preview-open.sh <PR number | dev> [local port]  -> http://localhost:<port>
set -euo pipefail
ID="${1:?usage: $0 <pr-number|dev> [local-port]}"
PORT="${2:-9000}"
NS="vaultai-pr-$ID"; [ "$ID" = "dev" ] && NS="vaultai-dev"
echo "Preview '$ID' -> http://localhost:$PORT   (Ctrl+C to stop)"
exec kubectl -n "$NS" port-forward svc/gateway "$PORT:80"
