#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GLOBAL_HELPER="$HOME/.codex/skills/task-handoff-state/scripts/queue_guidance.sh"
LOCAL_HELPER="$ROOT_DIR/skills/task-handoff-state/scripts/queue_guidance.sh"

if [ -x "$LOCAL_HELPER" ]; then
  HELPER_SCRIPT="$LOCAL_HELPER"
elif [ -x "$GLOBAL_HELPER" ]; then
  HELPER_SCRIPT="$GLOBAL_HELPER"
else
  echo "No guidance-queue helper found. Install Campfire skills or use the bundled repo copy." >&2
  exit 1
fi

"$HELPER_SCRIPT" --root "$ROOT_DIR" "$@"
