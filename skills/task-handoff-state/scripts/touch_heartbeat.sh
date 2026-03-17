#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_HELPER="${SQL_HELPER:-$SCRIPT_DIR/campfire_sql.py}"
STATE=""
MILESTONE_ID=""
MILESTONE_TITLE=""
SLICE_ID=""
SLICE_TITLE=""
SUMMARY_TEXT=""
TOUCHED_PATH=""
SESSION_STARTED_AT=""
SOURCE_NAME="touch_heartbeat.sh"

usage() {
  cat <<'EOF'
Usage:
  touch_heartbeat.sh [--root /path/to/workspace] [--state active|idle|blocked|waiting_on_decision|completed] [--milestone-id id] [--milestone-title title] [--slice-id id] [--slice-title title] [--summary text] [--touched-path path] [--session-started-at iso8601] [--source name] <task-slug>
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --state)
      STATE="$2"
      shift 2
      ;;
    --milestone-id)
      MILESTONE_ID="$2"
      shift 2
      ;;
    --milestone-title)
      MILESTONE_TITLE="$2"
      shift 2
      ;;
    --slice-id)
      SLICE_ID="$2"
      shift 2
      ;;
    --slice-title)
      SLICE_TITLE="$2"
      shift 2
      ;;
    --summary)
      SUMMARY_TEXT="$2"
      shift 2
      ;;
    --touched-path)
      TOUCHED_PATH="$2"
      shift 2
      ;;
    --session-started-at)
      SESSION_STARTED_AT="$2"
      shift 2
      ;;
    --source)
      SOURCE_NAME="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 1
fi

TASK_SLUG="$1"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
TASK_ROOT="$(python3 "$SQL_HELPER" show-project --root "$ROOT_DIR" --field task_root)"
TASK_DIR="$ROOT_DIR/$TASK_ROOT/$TASK_SLUG"
CHECKPOINT_FILE="$TASK_DIR/checkpoints.json"
HEARTBEAT_FILE="$TASK_DIR/heartbeat.json"
SESSION_LOG="$TASK_DIR/logs/session.log"

if [ ! -d "$TASK_DIR" ]; then
  echo "Task not found: $TASK_DIR" >&2
  exit 1
fi

for required in "$CHECKPOINT_FILE"; do
  if [ ! -f "$required" ]; then
    echo "Missing required task file: $required" >&2
    exit 1
  fi
done

mkdir -p "$TASK_DIR/logs"

export CHECKPOINT_FILE HEARTBEAT_FILE SESSION_LOG TASK_SLUG STATE MILESTONE_ID MILESTONE_TITLE SLICE_ID SLICE_TITLE SUMMARY_TEXT TOUCHED_PATH SESSION_STARTED_AT SOURCE_NAME

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


checkpoint_path = Path(os.environ["CHECKPOINT_FILE"])
heartbeat_path = Path(os.environ["HEARTBEAT_FILE"])
session_log_path = Path(os.environ["SESSION_LOG"])
task_slug = os.environ["TASK_SLUG"]
requested_state = os.environ["STATE"].strip()
requested_milestone_id = os.environ["MILESTONE_ID"].strip()
requested_milestone_title = os.environ["MILESTONE_TITLE"].strip()
requested_slice_id = os.environ["SLICE_ID"].strip()
requested_slice_title = os.environ["SLICE_TITLE"].strip()
requested_summary = os.environ["SUMMARY_TEXT"].strip()
requested_touched = os.environ["TOUCHED_PATH"].strip()
requested_session_started_at = os.environ["SESSION_STARTED_AT"].strip()
source_name = os.environ["SOURCE_NAME"].strip() or "touch_heartbeat.sh"

checkpoint = load_json(checkpoint_path)
current = checkpoint.get("current", {})
if not isinstance(current, dict):
    current = {}

heartbeat = load_json(heartbeat_path)
now = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")

derived_state = requested_state
if not derived_state:
    status = str(checkpoint.get("status", "")).strip()
    if status == "in_progress":
        derived_state = "active"
    elif status in {"blocked", "waiting_on_decision", "completed"}:
        derived_state = status
    else:
        derived_state = "idle"

session_started_at = requested_session_started_at or heartbeat.get("session_started_at", "")
if derived_state == "active" and not session_started_at:
    session_started_at = now

payload = {
    "task_slug": task_slug,
    "state": derived_state,
    "session_started_at": session_started_at,
    "last_seen_at": now,
    "milestone_id": requested_milestone_id or str(current.get("milestone_id", "")).strip(),
    "milestone_title": requested_milestone_title or str(current.get("milestone_title", "")).strip(),
    "slice_id": requested_slice_id or str(current.get("slice_id", "")).strip(),
    "slice_title": requested_slice_title or str(current.get("slice_title", "")).strip(),
    "summary": requested_summary or heartbeat.get("summary", ""),
    "touched_path": requested_touched or heartbeat.get("touched_path", ""),
    "source": source_name,
}

heartbeat_path.write_text(json.dumps(payload, indent=2) + "\n")

session_log_path.parent.mkdir(parents=True, exist_ok=True)
with session_log_path.open("a", encoding="utf8") as handle:
    handle.write(json.dumps(payload) + "\n")

print(f"Heartbeat updated: {task_slug}")
print(f"  state: {payload['state']}")
print(f"  milestone: {payload['milestone_id']}")
print(f"  slice: {payload['slice_id']}")
print(f"  last_seen_at: {payload['last_seen_at']}")
PY
