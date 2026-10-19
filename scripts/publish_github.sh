#!/usr/bin/env bash
# Create the GitHub repo (if missing) and push main.
#
# Usage:
#   ./scripts/publish_github.sh            # public repo
#   ./scripts/publish_github.sh --private  # private repo
#
# Requires: gh (brew install gh) + gh auth login
set -euo pipefail

OWNER="nongxinshengxin"
REPO="nature-genome-plot"
VIS="public"
[[ "${1:-}" == "--private" ]] && VIS="private"

command -v gh >/dev/null || { echo "gh not installed: brew install gh"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "not logged in: run 'gh auth login'"; exit 1; }

if ! gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
  gh repo create "$OWNER/$REPO" "--$VIS" \
    --description "Nature-grade genome / pangenome / population-genomics figures: 12 archetypes, 39 style presets, runnable R templates."
fi

git remote get-url origin >/dev/null 2>&1 || \
  git remote add origin "https://github.com/$OWNER/$REPO.git"

git push -u origin main
echo "done: https://github.com/$OWNER/$REPO"
