#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"

usage() {
  cat <<'EOF'
Usage:
  refresh_registry.sh [--root /path/to/workspace]
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
AUTONOMOUS_DIR="$ROOT_DIR/.autonomous"
REGISTRY_DIR="$ROOT_DIR/.campfire"
REGISTRY_FILE="$REGISTRY_DIR/registry.json"

mkdir -p "$REGISTRY_DIR"

export ROOT_DIR AUTONOMOUS_DIR REGISTRY_FILE

python3 <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


root_dir = Path(os.environ["ROOT_DIR"])
autonomous_dir = Path(os.environ["AUTONOMOUS_DIR"])
registry_file = Path(os.environ["REGISTRY_FILE"])

tasks = []
if autonomous_dir.exists():
    for task_dir in sorted(p for p in autonomous_dir.iterdir() if p.is_dir()):
        checkpoint = load_json(task_dir / "checkpoints.json")
        if not checkpoint:
            continue
        heartbeat = load_json(task_dir / "heartbeat.json")
        current = checkpoint.get("current", {})
        if not isinstance(current, dict):
            current = {}
        execution = checkpoint.get("execution", {})
        if not isinstance(execution, dict):
            execution = {}
        last_run = checkpoint.get("last_run", {})
        if not isinstance(last_run, dict):
            last_run = {}
        queued = execution.get("queued_milestones", [])
        queued_count = len(queued) if isinstance(queued, list) else 0
        tasks.append(
            {
                "task_slug": checkpoint.get("task_slug", task_dir.name),
                "task_dir": str(task_dir),
                "status": checkpoint.get("status", "ready"),
                "phase": checkpoint.get("phase", "planning"),
                "current": {
                    "milestone_id": current.get("milestone_id", ""),
                    "milestone_title": current.get("milestone_title", ""),
                    "slice_id": current.get("slice_id", ""),
                    "slice_title": current.get("slice_title", ""),
                },
                "queued_count": queued_count,
                "last_updated": checkpoint.get("last_updated", ""),
                "last_run": {
                    "stop_reason": last_run.get("stop_reason", ""),
                    "started_at": last_run.get("started_at", ""),
                    "ended_at": last_run.get("ended_at", ""),
                    "summary": last_run.get("summary", ""),
                },
                "heartbeat": {
                    "state": heartbeat.get("state", ""),
                    "last_seen_at": heartbeat.get("last_seen_at", ""),
                    "session_started_at": heartbeat.get("session_started_at", ""),
                    "summary": heartbeat.get("summary", ""),
                    "touched_path": heartbeat.get("touched_path", ""),
                },
            }
        )

payload = {
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "root": str(root_dir),
    "task_count": len(tasks),
    "tasks": tasks,
}

registry_file.write_text(json.dumps(payload, indent=2) + "\n")
print(f"Registry refreshed: {registry_file}")
print(f"  task_count: {len(tasks)}")
PY
