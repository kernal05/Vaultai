#!/usr/bin/env bash
# One command: minikube -> images -> push chart -> Argo CD -> dev app -> (optional) PR previews
# Usage: ./scripts/30-all-in-one.sh [--rebuild] [--previews | --no-previews]
set -euo pipefail
cd "$(dirname "$0")/.."

STEP=0
step(){ STEP=$((STEP+1)); echo; echo "━━ [$STEP] $*"; }
REBUILD=0; PREVIEWS=ask
for a in "$@"; do
  case "$a" in
    --rebuild) REBUILD=1;;
    --previews) PREVIEWS=yes;;
    --no-previews) PREVIEWS=no;;
    *) echo "unknown option: $a"; exit 1;;
  esac
done

step "Checks"
for t in kubectl minikube docker git curl; do
  command -v "$t" >/dev/null || { echo "missing tool: $t"; exit 1; }
done
if [ ! -f docker-compose.yml ] || [ ! -d charts/vaultai-preview ] || [ ! -d gitops ]; then
  echo "Run this from ~/vaultai after unzipping the bundle."; exit 1
fi
BR=$(git branch --show-current)
if [ "$BR" != "main" ]; then
  echo "You are on '$BR'. Argo's dev app tracks main - run: git checkout main"; exit 1
fi
AVAIL=$(free -m | awk '/^Mem:/{print $7}')
echo "available RAM: ${AVAIL}Mi"
if [ "$AVAIL" -lt 1500 ]; then
  echo "WARNING: low memory. Stop other containers first (docker ps), then re-run."
fi

step "minikube"
minikube status >/dev/null 2>&1 || minikube start
kubectl config use-context minikube >/dev/null
kubectl get nodes
if kubectl get ns ims-app >/dev/null 2>&1; then
  echo "Pausing old ims-app to free RAM (resume: kubectl -n ims-app scale deploy --all --replicas=1)"
  kubectl -n ims-app scale deploy --all --replicas=0
fi

step "VaultAI images inside minikube"
IMGS=$(minikube image ls 2>/dev/null || true)
if [ "$REBUILD" = 1 ] || ! grep -q 'vaultai-api:local' <<<"$IMGS" || ! grep -q 'vaultai-frontend:local' <<<"$IMGS"; then
  ./scripts/10-minikube-build.sh
else
  echo "already present (use --rebuild to force)"
fi

step "Push chart + gitops to GitHub (Argo reads from Git, not from your laptop)"
git add charts gitops scripts docs
if git diff --cached --quiet; then
  echo "nothing new to commit"
else
  git commit -q -m "Add Argo CD GitOps + PR preview chart"
fi
git push origin main || { echo "push rejected - rebasing on remote..."; git pull --rebase origin main && git push origin main; }
if curl -fsI https://raw.githubusercontent.com/kernal05/Vaultai/main/charts/vaultai-preview/Chart.yaml >/dev/null; then
  echo "chart is visible on GitHub main"
else
  echo "chart NOT visible on GitHub yet - check the push"; exit 1
fi

step "Install Argo CD"
./scripts/21-argocd-install.sh

step "Deploy the dev Application"
./scripts/24-argocd-apply.sh dev >/dev/null
echo "Waiting for vaultai-dev to become Synced/Healthy (up to 5 min)..."
S="-/-"
for i in $(seq 1 60); do
  S=$(kubectl -n argocd get application vaultai-dev -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || echo "-/-")
  echo "  [$((i*5))s] sync/health = $S"
  [ "$S" = "Synced/Healthy" ] && break
  sleep 5
done
echo
kubectl -n vaultai-dev get pods 2>/dev/null || true
if [ "$S" != "Synced/Healthy" ]; then
  echo
  echo "vaultai-dev is not healthy yet. Diagnostics (paste this to Claude):"
  kubectl -n argocd get application vaultai-dev -o jsonpath='{range .status.conditions[*]}{.type}: {.message}{"\n"}{end}' 2>/dev/null || true
  kubectl -n vaultai-dev describe pods 2>/dev/null | grep -E 'Warning|Failed|Error|Back-off' | head -15 || true
  echo "--- api logs"; kubectl -n vaultai-dev logs deploy/api --tail=25 2>/dev/null || true
  exit 1
fi

step "Optional: PR previews"
if [ "$PREVIEWS" = ask ]; then
  read -rp "Set up PR previews now? (needs a GitHub token) [y/N] " ANS
  if [[ "$ANS" =~ ^[Yy]$ ]]; then PREVIEWS=yes; else PREVIEWS=no; fi
fi
if [ "$PREVIEWS" = yes ]; then
  ./scripts/23-argocd-github-token.sh
  ./scripts/24-argocd-apply.sh previews
else
  echo "skipped (later: ./scripts/23-argocd-github-token.sh && ./scripts/24-argocd-apply.sh previews)"
fi

cat <<'DONE'

━━ DONE. What to do next (each in its own terminal, they stay in the foreground):
  Argo CD UI     ./scripts/22-argocd-ui.sh        -> https://localhost:8080
  Dev app        ./scripts/26-preview-open.sh dev -> http://localhost:9000
  Drift test     kubectl -n vaultai-dev scale deploy/api --replicas=3   (watch it self-heal)
  PR demo        ./scripts/25-demo-pr.sh          (needs previews enabled)
  Tear down      ./scripts/27-argocd-teardown.sh
DONE
