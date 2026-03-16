#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$ROOT_DIR/skills}"
HELPER_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/promote_improvement.sh"

if [ ! -x "$HELPER_SCRIPT" ]; then
  echo "Campfire promote_improvement helper not found or not executable: $HELPER_SCRIPT" >&2
  exit 1
fi

"$HELPER_SCRIPT" --root "$ROOT_DIR" "$@"
