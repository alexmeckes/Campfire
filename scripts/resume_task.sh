#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GLOBAL_RESUME="$HOME/.codex/skills/task-handoff-state/scripts/resume_task.sh"
LOCAL_RESUME="$ROOT_DIR/skills/task-handoff-state/scripts/resume_task.sh"

if [ -x "$LOCAL_RESUME" ]; then
  RESUME_SCRIPT="$LOCAL_RESUME"
elif [ -x "$GLOBAL_RESUME" ]; then
  RESUME_SCRIPT="$GLOBAL_RESUME"
else
  echo "No task-state resume script found. Install Campfire skills or use the bundled repo copy." >&2
  exit 1
fi

"$RESUME_SCRIPT" --root "$ROOT_DIR" "$@"
