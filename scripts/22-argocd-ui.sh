#!/usr/bin/env bash
# Prints the admin password to YOUR terminal only, then port-forwards the UI.
set -euo pipefail
PW=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)
echo "Argo CD UI:  https://localhost:8080   (accept the self-signed cert warning)"
echo "Username:    admin"
if [ -n "$PW" ]; then echo "Password:    $PW"; else echo "Password:    (initial secret not found - already rotated/deleted?)"; fi
echo "Keep this terminal open. Ctrl+C stops the port-forward."
exec kubectl -n argocd port-forward svc/argocd-server 8080:443
