#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$HOME/.codex/skills}"
HELPER_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/automation_prompt_helper.sh"

if [ ! -x "$HELPER_SCRIPT" ]; then
  echo "Campfire automation prompt helper not found: $HELPER_SCRIPT" >&2
  echo "Set CAMPFIRE_SKILLS_ROOT or install Campfire skills with ./scripts/install_skills.sh." >&2
  exit 1
fi

"$HELPER_SCRIPT" --root "$ROOT_DIR" "$@"
