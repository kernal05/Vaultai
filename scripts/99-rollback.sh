#!/usr/bin/env bash
# Roll back to a specific previously-built image tag.
# Usage: ./99-rollback.sh <image_tag>
set -euo pipefail
cd "$(dirname "$0")/.."

TAG="${1:?Usage: 99-rollback.sh <image_tag>}"

echo "Rolling back VaultAI to image tag: $TAG"
IMAGE_TAG="$TAG" docker compose --env-file .env up -d
docker compose ps
