#!/usr/bin/env bash
# Creates the secret the PR generator uses to call the GitHub API.
# Token: GitHub -> Settings -> Developer settings -> Fine-grained tokens
#   Repository: only kernal05/Vaultai | Permissions: Pull requests = Read, Contents = Read, Metadata = Read
# Input is hidden and never echoed / never goes into chat or shell history.
set -euo pipefail
read -rsp "GitHub token (hidden): " TOKEN; echo
[ -n "$TOKEN" ] || { echo "empty token, aborting"; exit 1; }
printf %s "$TOKEN" | kubectl -n argocd create secret generic github-token \
  --from-file=token=/dev/stdin --dry-run=client -o yaml | kubectl apply -f -
unset TOKEN
echo "secret argocd/github-token created"
