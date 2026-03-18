#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REGISTRY_FILE="$ROOT_DIR/.campfire/registry.json"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$HOME/.codex/skills}"
TOUCH_HEARTBEAT_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/touch_heartbeat.sh"
REFRESH_REGISTRY_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/refresh_registry.sh"
HOOK_HELPER="$SCRIPT_DIR/campfire-hook-helper.py"

if [ ! -x "$TOUCH_HEARTBEAT_SCRIPT" ] || [ ! -x "$REFRESH_REGISTRY_SCRIPT" ]; then
  exit 0
fi

TASK_SLUG="$(python3 "$HOOK_HELPER" active-task "$REGISTRY_FILE")"

if [ -z "$TASK_SLUG" ]; then
  exit 0
fi

"$TOUCH_HEARTBEAT_SCRIPT" --root "$ROOT_DIR" --state active --source "claude-post-tool.sh" --summary "Claude Code tool activity." "$TASK_SLUG" >/dev/null
"$REFRESH_REGISTRY_SCRIPT" --root "$ROOT_DIR" >/dev/null
