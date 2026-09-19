#!/usr/bin/env bash
# ./scripts/27-argocd-teardown.sh          -> remove ApplicationSet + dev app (cascades to all preview namespaces)
# ./scripts/27-argocd-teardown.sh --purge  -> also uninstall Argo CD itself
set -euo pipefail
cd "$(dirname "$0")/.."
kubectl delete -f gitops/applicationset-pr-previews.yaml --ignore-not-found
kubectl delete -f gitops/application-dev.yaml --ignore-not-found
kubectl delete -f gitops/appproject-previews.yaml --ignore-not-found
if [ "${1:-}" = "--purge" ]; then
  kubectl delete -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION:-stable}/manifests/install.yaml" --ignore-not-found
  kubectl delete namespace argocd --ignore-not-found
fi
kubectl get ns | grep -E 'vaultai-(pr|dev)' || echo "no preview namespaces left"
