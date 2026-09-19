#!/usr/bin/env bash
# ./scripts/25-demo-pr.sh          -> new branch + commit + push + open PR
# ./scripts/25-demo-pr.sh update   -> push another commit to the CURRENT branch (watch Argo re-sync to the new SHA)
# ./scripts/25-demo-pr.sh close    -> close the PR for the CURRENT branch (watch the env get torn down)
set -euo pipefail
cd "$(dirname "$0")/.."
ACTION="${1:-new}"

case "$ACTION" in
  new)
    git checkout main && git pull --ff-only
    BR="feature/preview-demo-$(date +%H%M%S)"
    git checkout -b "$BR"
    mkdir -p docs && echo "preview demo $(date -Is)" >> docs/preview-demo.md
    git add docs/preview-demo.md && git commit -m "docs: preview environment demo"
    git push -u origin "$BR"
    if command -v gh >/dev/null; then
      gh pr create --base main --head "$BR" --title "Preview demo ($BR)" --body "Testing Argo CD PR generator"
    else
      echo "Open this in your browser and click 'Create pull request':"
      echo "  https://github.com/kernal05/Vaultai/compare/main...${BR}?expand=1"
    fi
    ;;
  update)
    echo "update $(date -Is)" >> docs/preview-demo.md
    git add docs/preview-demo.md && git commit -m "docs: preview demo update"
    git push
    ;;
  close)
    command -v gh >/dev/null && gh pr close "$(git branch --show-current)" --delete-branch || echo "Close the PR in the GitHub UI"
    ;;
  *) echo "usage: $0 [new|update|close]"; exit 1;;
esac
echo
echo "Argo polls every ~120s. To skip the wait:  kubectl -n argocd rollout restart deploy/argocd-applicationset-controller"
echo "Then:  kubectl -n argocd get applications ; kubectl get ns | grep vaultai-pr"
