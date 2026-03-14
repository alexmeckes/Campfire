#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GLOBAL_INIT="$HOME/.codex/skills/task-handoff-state/scripts/init_task.sh"
LOCAL_INIT="$ROOT_DIR/skills/task-handoff-state/scripts/init_task.sh"

if [ -x "$LOCAL_INIT" ]; then
  INIT_SCRIPT="$LOCAL_INIT"
elif [ -x "$GLOBAL_INIT" ]; then
  INIT_SCRIPT="$GLOBAL_INIT"
else
  echo "No task-state init script found. Install Campfire skills or use the bundled repo copy." >&2
  exit 1
fi

"$INIT_SCRIPT" --root "$ROOT_DIR" "$@"
