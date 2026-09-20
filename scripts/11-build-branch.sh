#!/usr/bin/env bash
# Builds the VaultAI images for the CURRENT commit INSIDE minikube, tagged with the commit's
# 8-character SHA. The PR-preview ApplicationSet passes the same 8 characters (head_short_sha)
# to the chart as the image tag, so the preview runs exactly this commit.
#
# Order matters: commit -> run this script -> push -> open/update the PR.
# If the image is not in minikube when the preview starts, the pods sit in ImagePullBackOff.
set -euo pipefail
cd "$(dirname "$0")/.."

TAG="$(git rev-parse --short=8 HEAD)"

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "WARNING: uncommitted changes. The images will contain them, but the tag ($TAG) names the last commit."
  echo "         Commit first, or the preview will not match what you tested."
fi
if UNPUSHED="$(git rev-list --count '@{u}..HEAD' 2>/dev/null)" && [ "$UNPUSHED" != "0" ]; then
  echo "NOTE: $UNPUSHED commit(s) not pushed yet. Push before opening or updating the PR."
fi

minikube status >/dev/null 2>&1 || minikube start
eval "$(minikube docker-env)"

export IMAGE_TAG="$TAG"
export POSTGRES_PASSWORD=build-only GRAFANA_PASSWORD=build-only GRAFANA_ADMIN_PASSWORD=build-only

if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi
$DC build

echo
echo "Images for commit $TAG inside minikube:"
minikube image ls | grep -i "vaultai-.*:$TAG"
echo
echo "Next: git push, then open or update the PR. The preview will use tag $TAG."
