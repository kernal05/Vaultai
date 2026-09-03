#!/usr/bin/env bash
# Run this on YOUR LAPTOP (WSL Ubuntu), from inside the unzipped vaultai/ folder.
# Pushes the project to https://github.com/kernal05/Vaultai
set -euo pipefail

REPO_URL="https://github.com/kernal05/Vaultai.git"

if [ ! -d .git ]; then
  git init
  git branch -M main
fi

git add .
git commit -m "Initial VaultAI scaffold: compose, api, ci/cd, isolation" || echo "Nothing new to commit"

if ! git remote | grep -q origin; then
  git remote add origin "$REPO_URL"
fi

echo "Pushing to $REPO_URL ..."
git push -u origin main

echo ""
echo "Done. Check: $REPO_URL"
