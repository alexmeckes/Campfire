#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REGISTRY_FILE="$ROOT_DIR/.campfire/registry.json"

# PreToolUse can block by exiting 2 and writing a short reason to stderr.
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

if status == "waiting_on_decision":
    print(
        f"Campfire task {task_slug} is waiting on a real decision boundary. "
        "Stop and ask for the missing decision before editing files.",
        file=sys.stderr,
    )
    raise SystemExit(2)

if status == "in_progress" and slice_id:
    raise SystemExit(0)

if status in {"in_progress", "ready", "validated", "blocked"}:
    print(
        f"Campfire task {task_slug} does not have an active slice for edits yet. "
        f"Run ./scripts/resume_task.sh {task_slug} or start the next slice before editing files.",
        file=sys.stderr,
    )
    raise SystemExit(2)
PY
