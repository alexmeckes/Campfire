#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REGISTRY_FILE="$ROOT_DIR/.campfire/registry.json"

python3 - "$REGISTRY_FILE" <<'PY'
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
    print("campfire no-task")
    raise SystemExit(0)

selected = sorted(tasks, key=task_priority)[0]
task_slug = str(selected.get("task_slug", "")).strip() or "task"
status = str(selected.get("status", "unknown")).strip() or "unknown"
current = selected.get("current", {})
if not isinstance(current, dict):
    current = {}
milestone_id = str(current.get("milestone_id", "")).strip()

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
