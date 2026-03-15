#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GLOBAL_REFRESH="$HOME/.codex/skills/task-handoff-state/scripts/refresh_registry.sh"
LOCAL_REFRESH="$ROOT_DIR/skills/task-handoff-state/scripts/refresh_registry.sh"

if [ -x "$LOCAL_REFRESH" ]; then
  REFRESH_SCRIPT="$LOCAL_REFRESH"
elif [ -x "$GLOBAL_REFRESH" ]; then
  REFRESH_SCRIPT="$GLOBAL_REFRESH"
else
  echo "No registry refresh helper found. Install Campfire skills or use the bundled repo copy." >&2
  exit 1
fi

"$REFRESH_SCRIPT" --root "$ROOT_DIR" "$@"
