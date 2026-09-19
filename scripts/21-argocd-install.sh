#!/usr/bin/env bash
set -euo pipefail
ARGOCD_VERSION="${ARGOCD_VERSION:-stable}"   # e.g. ARGOCD_VERSION=v3.1.0 to pin

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# --server-side is required: the ApplicationSet CRD is too big for client-side apply
# ("metadata.annotations: Too long").
kubectl apply -n argocd --server-side --force-conflicts \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

# Save laptop RAM: we use neither SSO (dex) nor notifications in this lab.
kubectl -n argocd scale deploy argocd-dex-server argocd-notifications-controller --replicas=0 2>/dev/null || true

echo "Waiting for Argo CD components..."
for d in argocd-redis argocd-repo-server argocd-server argocd-applicationset-controller; do
  kubectl -n argocd rollout status "deploy/$d" --timeout=300s
done
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

echo
kubectl -n argocd get pods
echo
echo "Argo CD is up. Next: ./scripts/22-argocd-ui.sh"
