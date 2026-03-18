#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$HOME/.codex/skills}"
HELPER_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/record_improvement_candidate.sh"

if [ ! -x "$HELPER_SCRIPT" ]; then
  echo "Campfire record_improvement_candidate helper not found or not executable: $HELPER_SCRIPT" >&2
  exit 1
fi

"$HELPER_SCRIPT" --root "$ROOT_DIR" "$@"
