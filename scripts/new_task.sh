#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GLOBAL_BOOTSTRAP="$HOME/.codex/skills/task-handoff-state/scripts/bootstrap_task.sh"
LOCAL_BOOTSTRAP="$ROOT_DIR/skills/task-handoff-state/scripts/bootstrap_task.sh"

if [ -x "$LOCAL_BOOTSTRAP" ]; then
  BOOTSTRAP_SCRIPT="$LOCAL_BOOTSTRAP"
elif [ -x "$GLOBAL_BOOTSTRAP" ]; then
  BOOTSTRAP_SCRIPT="$GLOBAL_BOOTSTRAP"
else
  echo "No task bootstrap script found. Install Campfire skills or use the bundled repo copy." >&2
  exit 1
fi

"$BOOTSTRAP_SCRIPT" --root "$ROOT_DIR" "$@"
