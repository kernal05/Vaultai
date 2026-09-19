#!/usr/bin/env bash
# Usage: ./scripts/24-argocd-apply.sh dev        -> AppProject + single Application (learn sync/drift)
#        ./scripts/24-argocd-apply.sh previews   -> AppProject + ApplicationSet (PR generator)
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-}"
[ "$MODE" = "dev" ] || [ "$MODE" = "previews" ] || { echo "usage: $0 dev|previews"; exit 1; }

kubectl apply -f gitops/appproject-previews.yaml
if [ "$MODE" = "dev" ]; then
  kubectl apply -f gitops/application-dev.yaml
else
  kubectl -n argocd get secret github-token >/dev/null 2>&1 || { echo "Run ./scripts/23-argocd-github-token.sh first"; exit 1; }
  kubectl apply -f gitops/applicationset-pr-previews.yaml
fi
echo
kubectl -n argocd get applicationsets,applications 2>/dev/null || true
echo
echo "Watch:  kubectl -n argocd get applications -w"
