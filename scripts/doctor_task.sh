#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$ROOT_DIR/skills}"
DOCTOR_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/doctor_task.sh"

if [ ! -x "$DOCTOR_SCRIPT" ]; then
  echo "Campfire doctor_task script not found or not executable: $DOCTOR_SCRIPT" >&2
  exit 1
fi

"$DOCTOR_SCRIPT" --root "$ROOT_DIR" "$@"
