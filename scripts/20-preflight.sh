#!/usr/bin/env bash
# Read-only checks. Changes nothing.
set -uo pipefail
cd "$(dirname "$0")/.."
FAIL=0
ok(){ echo "  [ok]   $*"; }; warn(){ echo "  [warn] $*"; }; bad(){ echo "  [FAIL] $*"; FAIL=1; }

echo "== tools"
for t in kubectl minikube docker git curl; do command -v "$t" >/dev/null && ok "$t" || bad "$t missing"; done
command -v gh >/dev/null && ok "gh (optional, opens PRs from the terminal)" || warn "gh not installed - demo script will print a browser link instead"

echo "== minikube"
if minikube status >/dev/null 2>&1; then
  ok "running"
  echo "  node allocatable memory: $(kubectl get nodes -o jsonpath='{.items[0].status.allocatable.memory}' 2>/dev/null)"
  echo "  (Argo CD + a couple of previews want roughly 4Gi. If lower: minikube stop; minikube start --memory=4096 --cpus=2)"
else
  bad "not running -> minikube start --memory=4096 --cpus=2"
fi

echo "== images inside minikube (chart values must match these names/tags)"
minikube image ls 2>/dev/null | grep -i vaultai || warn "no vaultai images found -> run ./scripts/10-minikube-build.sh"

echo "== repo"
ORIGIN=$(git remote get-url origin 2>/dev/null || true); echo "  origin: ${ORIGIN:-none}"
CODE=$(curl -s -o /dev/null -w '%{http_code}' https://api.github.com/repos/kernal05/Vaultai || true)
[ "$CODE" = "200" ] && ok "repo is public (Argo can clone without credentials)" || warn "GitHub API returned $CODE - repo may be private (Argo would then need repo credentials)"

echo "== hints from docker-compose.yml (ports / env names for charts/vaultai-preview/values.yaml)"
if [ -f docker-compose.yml ]; then
  grep -nE 'image:|build:|ports:|- "[0-9]+:[0-9]+"|expose:|DATABASE|POSTGRES|healthcheck|test:' docker-compose.yml || true
else
  warn "no docker-compose.yml in repo root"
fi
echo
[ "$FAIL" = 0 ] && echo "Preflight OK" || { echo "Fix the FAIL lines first"; exit 1; }
