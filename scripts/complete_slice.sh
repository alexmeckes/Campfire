#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GLOBAL_COMPLETE="$HOME/.codex/skills/task-handoff-state/scripts/complete_slice.sh"
LOCAL_COMPLETE="$ROOT_DIR/skills/task-handoff-state/scripts/complete_slice.sh"

if [ -x "$LOCAL_COMPLETE" ]; then
  COMPLETE_SCRIPT="$LOCAL_COMPLETE"
elif [ -x "$GLOBAL_COMPLETE" ]; then
  COMPLETE_SCRIPT="$GLOBAL_COMPLETE"
else
  echo "No complete-slice helper found. Install Campfire skills or use the bundled repo copy." >&2
  exit 1
fi

"$COMPLETE_SCRIPT" --root "$ROOT_DIR" "$@"
