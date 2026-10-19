#!/usr/bin/env bash
# Install nature-genome-plot as a skill for DSH, Claude Code and Codex.
#
# Usage:
#   ./install.sh            # all agents, user level
#   ./install.sh claude     # one agent: dsh | claude | codex
#   ./install.sh project    # project level (.claude/skills, .agents/skills)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
NAME="nature-genome-plot"
MODE="${1:-all}"

case "$MODE" in
  all)      DESTS=("$HOME/.dsh/skills" "$HOME/.claude/skills" "$HOME/.agents/skills") ;;
  dsh)      DESTS=("$HOME/.dsh/skills") ;;
  claude)   DESTS=("$HOME/.claude/skills") ;;
  codex)    DESTS=("$HOME/.agents/skills") ;;
  project)  DESTS=(".claude/skills" ".agents/skills") ;;
  *) echo "unknown mode: $MODE (use all|dsh|claude|codex|project)"; exit 1 ;;
esac

for dest in "${DESTS[@]}"; do
  mkdir -p "$dest"
  ln -sfn "$ROOT" "$dest/$NAME"
  echo "linked $dest/$NAME -> $ROOT"
done

echo
echo "verify:"
echo "  Rscript scripts/install_deps.R --check"
echo "  python3 scripts/validate/catalog_check.py"
echo
echo "in the agent: run /skills (Claude Code, Codex) or restart DSH, then ask for a genome figure."
