#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_CONTEXT_FILE="$ROOT_DIR/.campfire/project_context.json"
REGISTRY_FILE="$ROOT_DIR/.campfire/registry.json"

# SessionStart hooks can inject stdout directly as context, so keep the payload short.
python3 - "$ROOT_DIR" "$PROJECT_CONTEXT_FILE" "$REGISTRY_FILE" <<'PY'
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


root = Path(sys.argv[1])
project_context = load_json(Path(sys.argv[2]))
registry = load_json(Path(sys.argv[3]))

if not project_context and not registry:
    raise SystemExit(0)

project_name = str(project_context.get("project_name", root.name)).strip() or root.name
task_root = str(project_context.get("task_root", ".autonomous")).strip() or ".autonomous"
tasks = registry.get("tasks", [])
if not isinstance(tasks, list):
    tasks = []

print("Campfire project detected.")
print(f"project: {project_name}")
print(f"task_root: {task_root}")

if not tasks:
    print("task: none")
    print("next_helper: ./scripts/new_task.sh \"objective\"")
    raise SystemExit(0)

selected = sorted(tasks, key=task_priority)[0]
task_slug = str(selected.get("task_slug", "")).strip()
status = str(selected.get("status", "unknown")).strip() or "unknown"
phase = str(selected.get("phase", "")).strip()

task_context_path = Path(str(selected.get("task_dir", "")).strip()) / "task_context.json"
task_context = load_json(task_context_path)
current = task_context.get("current", {})
if not isinstance(current, dict):
    current = {}
last_run = selected.get("last_run", {})
if not isinstance(last_run, dict):
    last_run = {}

milestone_id = str(current.get("milestone_id", "")).strip()
milestone_title = str(current.get("milestone_title", "")).strip()
slice_title = str(current.get("slice_title", "")).strip()
stop_reason = str(last_run.get("stop_reason", "")).strip()

print(f"task: {task_slug}")
print(f"status: {status}")
if phase:
    print(f"phase: {phase}")
if milestone_id:
    milestone_text = milestone_id
    if milestone_title:
        milestone_text = f"{milestone_id} - {milestone_title}"
    print(f"milestone: {milestone_text}")
if slice_title:
    print(f"slice: {slice_title}")
if stop_reason:
    print(f"stop_reason: {stop_reason}")
print(f"next_helper: ./scripts/resume_task.sh {task_slug}")

if status == "waiting_on_decision":
    print("decision_boundary: stop and ask for the missing decision before implementing more work.")
PY
