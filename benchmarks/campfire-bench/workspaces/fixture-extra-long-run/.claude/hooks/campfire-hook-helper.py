#!/usr/bin/env python3
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


def selected_task(registry_path: Path) -> dict:
    registry = load_json(registry_path)
    tasks = registry.get("tasks", [])
    if not isinstance(tasks, list) or not tasks:
        return {}
    selected = sorted(tasks, key=task_priority)[0]
    task_dir = Path(str(selected.get("task_dir", "")).strip())
    task_context = load_json(task_dir / "task_context.json")
    current = task_context.get("current", {})
    if not isinstance(current, dict):
        current = {}
    last_run = selected.get("last_run", {})
    if not isinstance(last_run, dict):
        last_run = {}
    return {
        "task_slug": str(selected.get("task_slug", "")).strip(),
        "status": str(selected.get("status", "unknown")).strip() or "unknown",
        "phase": str(selected.get("phase", "")).strip(),
        "task_dir": str(task_dir),
        "milestone_id": str(current.get("milestone_id", "")).strip(),
        "milestone_title": str(current.get("milestone_title", "")).strip(),
        "slice_id": str(current.get("slice_id", "")).strip(),
        "slice_title": str(current.get("slice_title", "")).strip(),
        "stop_reason": str(last_run.get("stop_reason", "")).strip(),
    }


def command_selected_task(registry_path: Path) -> int:
    payload = selected_task(registry_path)
    print(json.dumps(payload))
    return 0


def command_guard_action(registry_path: Path) -> int:
    payload = selected_task(registry_path)
    if not payload:
        print(json.dumps({"action": "allow"}))
        return 0

    status = payload["status"]
    task_slug = payload["task_slug"]
    slice_id = payload["slice_id"]

    if status == "waiting_on_decision":
        print(
            json.dumps(
                {
                    "action": "block",
                    "reason": (
                        f"Campfire task {task_slug} is waiting on a real decision boundary. "
                        "Stop and ask for the missing decision before editing files."
                    ),
                }
            )
        )
        return 0

    if status == "in_progress" and slice_id:
        print(json.dumps({"action": "allow"}))
        return 0

    if status in {"in_progress", "ready", "validated", "blocked"}:
        print(
            json.dumps(
                {
                    "action": "block",
                    "reason": (
                        f"Campfire task {task_slug} does not have an active slice for edits yet. "
                        f"Run ./scripts/resume_task.sh {task_slug} or start the next slice before editing files."
                    ),
                }
            )
        )
        return 0

    print(json.dumps({"action": "allow"}))
    return 0


def command_active_task(registry_path: Path) -> int:
    payload = selected_task(registry_path)
    if not payload:
        return 0
    if payload["status"] == "in_progress" and payload["slice_id"] and payload["task_slug"]:
        print(payload["task_slug"])
    return 0


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        raise SystemExit("Usage: campfire-hook-helper.py <selected-task|guard-action|active-task> <registry-path>")

    command = argv[1]
    registry_path = Path(argv[2])

    if command == "selected-task":
        return command_selected_task(registry_path)
    if command == "guard-action":
        return command_guard_action(registry_path)
    if command == "active-task":
        return command_active_task(registry_path)

    raise SystemExit(f"Unknown command: {command}")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
