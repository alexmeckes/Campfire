#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GLOBAL_ENABLE="$HOME/.codex/skills/task-handoff-state/scripts/enable_rolling_mode.sh"
LOCAL_ENABLE="$ROOT_DIR/skills/task-handoff-state/scripts/enable_rolling_mode.sh"

if [ -x "$LOCAL_ENABLE" ]; then
  ENABLE_SCRIPT="$LOCAL_ENABLE"
elif [ -x "$GLOBAL_ENABLE" ]; then
  ENABLE_SCRIPT="$GLOBAL_ENABLE"
else
  echo "No rolling-mode helper found. Install Campfire skills or use the bundled repo copy." >&2
  exit 1
fi

"$ENABLE_SCRIPT" --root "$ROOT_DIR" "$@"
