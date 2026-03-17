#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REGISTRY_FILE="$ROOT_DIR/.campfire/registry.json"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$HOME/.codex/skills}"
TOUCH_HEARTBEAT_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/touch_heartbeat.sh"
REFRESH_REGISTRY_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/refresh_registry.sh"

if [ ! -x "$TOUCH_HEARTBEAT_SCRIPT" ] || [ ! -x "$REFRESH_REGISTRY_SCRIPT" ]; then
  exit 0
fi

TASK_SLUG="$(python3 - "$REGISTRY_FILE" <<'PY'
import json
import sys
from pathlib import Path


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def task_priority(task: dict) -> tuple[int, str]:
    status = str(task.get("status", "")).strip()
    priorities = {
        "in_progress": 0,
        "waiting_on_decision": 1,
        "blocked": 2,
        "ready": 3,
        "validated": 4,
        "completed": 5,
    }
    return priorities.get(status, 9), str(task.get("last_updated", ""))


registry = load_json(Path(sys.argv[1]))
tasks = registry.get("tasks", [])
if not isinstance(tasks, list) or not tasks:
    raise SystemExit(0)

selected = sorted(tasks, key=task_priority)[0]
task_slug = str(selected.get("task_slug", "")).strip()
status = str(selected.get("status", "")).strip()
task_dir = Path(str(selected.get("task_dir", "")).strip())
task_context = load_json(task_dir / "task_context.json")
current = task_context.get("current", {})
if not isinstance(current, dict):
    current = {}
slice_id = str(current.get("slice_id", "")).strip()

if status == "in_progress" and slice_id and task_slug:
    print(task_slug)
PY
)"

if [ -z "$TASK_SLUG" ]; then
  exit 0
fi

"$TOUCH_HEARTBEAT_SCRIPT" --root "$ROOT_DIR" --state active --source "claude-post-tool.sh" --summary "Claude Code tool activity." "$TASK_SLUG" >/dev/null
"$REFRESH_REGISTRY_SCRIPT" --root "$ROOT_DIR" >/dev/null
