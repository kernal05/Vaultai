#!/usr/bin/env bash
# Builds the VaultAI images INSIDE minikube's docker daemon (no registry, no push).
# Tags come from docker-compose.yml: ghcr.io/kernal05/vaultai-{frontend,api}:local
set -euo pipefail
cd "$(dirname "$0")/.."

minikube status >/dev/null 2>&1 || minikube start
eval "$(minikube docker-env)"

export IMAGE_TAG=local
# Only needed so compose can interpolate the file; nothing is run, only built.
export POSTGRES_PASSWORD=build-only GRAFANA_PASSWORD=build-only GRAFANA_ADMIN_PASSWORD=build-only

if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC build   # builds only services that have a build: section (frontend + api)

echo
echo "Images now inside minikube:"
minikube image ls | grep -i vaultai
