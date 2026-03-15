#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GLOBAL_START="$HOME/.codex/skills/task-handoff-state/scripts/start_slice.sh"
LOCAL_START="$ROOT_DIR/skills/task-handoff-state/scripts/start_slice.sh"

if [ -x "$LOCAL_START" ]; then
  START_SCRIPT="$LOCAL_START"
elif [ -x "$GLOBAL_START" ]; then
  START_SCRIPT="$GLOBAL_START"
else
  echo "No start-slice helper found. Install Campfire skills or use the bundled repo copy." >&2
  exit 1
fi

"$START_SCRIPT" --root "$ROOT_DIR" "$@"
