#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REGISTRY_FILE="$ROOT_DIR/.campfire/registry.json"
HOOK_HELPER="$SCRIPT_DIR/campfire-hook-helper.py"

SELECTED_JSON="$(python3 "$HOOK_HELPER" selected-task "$REGISTRY_FILE")"

if [ -z "$SELECTED_JSON" ] || [ "$SELECTED_JSON" = "{}" ]; then
  echo "campfire no-task"
  exit 0
fi

python3 - "$SELECTED_JSON" <<'PY'
import json
import sys

selected = json.loads(sys.argv[1])
task_slug = str(selected.get("task_slug", "")).strip() or "task"
status = str(selected.get("status", "unknown")).strip() or "unknown"
milestone_id = str(selected.get("milestone_id", "")).strip()

status_short = {
    "in_progress": "active",
    "waiting_on_decision": "decision",
    "blocked": "blocked",
    "ready": "ready",
    "validated": "validated",
    "completed": "done",
}.get(status, status)

parts = ["campfire", task_slug]
if milestone_id:
    parts.append(milestone_id)
parts.append(status_short)
print(" ".join(parts))
PY
