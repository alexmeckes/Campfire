#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_HELPER="${SQL_HELPER:-$SCRIPT_DIR/campfire_sql.py}"
STATUS="validated"
STOP_REASON=""
SUMMARY_TEXT=""
NEXT_STEP=""
NEXT_SLICE=""
EVENTS=()
STATE_OVERRIDE=""
REFRESH_REGISTRY=true

usage() {
  cat <<'EOF'
Usage:
  complete_slice.sh [--root /path/to/workspace] [--status validated|completed|blocked|waiting_on_decision] [--stop-reason reason] [--summary text] [--next-step text] [--next-slice text] [--event name] [--state active|idle|blocked|waiting_on_decision|completed] [--no-registry-refresh] <task-slug>
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --status)
      STATUS="$2"
      shift 2
      ;;
    --stop-reason)
      STOP_REASON="$2"
      shift 2
      ;;
    --summary)
      SUMMARY_TEXT="$2"
      shift 2
      ;;
    --next-step)
      NEXT_STEP="$2"
      shift 2
      ;;
    --next-slice)
      NEXT_SLICE="$2"
      shift 2
      ;;
    --event)
      EVENTS+=("$2")
      shift 2
      ;;
    --state)
      STATE_OVERRIDE="$2"
      shift 2
      ;;
    --no-registry-refresh)
      REFRESH_REGISTRY=false
      shift
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
TOUCH_HEARTBEAT_SCRIPT="$SCRIPT_DIR/touch_heartbeat.sh"
REFRESH_REGISTRY_SCRIPT="$SCRIPT_DIR/refresh_registry.sh"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to complete a slice" >&2
  exit 1
fi

TASK_ROOT="$(python3 "$SQL_HELPER" show-project --root "$ROOT_DIR" --field task_root)"
TASK_DIR="$ROOT_DIR/$TASK_ROOT/$TASK_SLUG"
CHECKPOINT_FILE="$TASK_DIR/checkpoints.json"
HANDOFF_FILE="$TASK_DIR/handoff.md"
PROGRESS_FILE="$TASK_DIR/progress.md"

if [ ! -d "$TASK_DIR" ]; then
  echo "Task not found: $TASK_DIR" >&2
  exit 1
fi

for required in "$CHECKPOINT_FILE" "$HANDOFF_FILE" "$PROGRESS_FILE"; do
  if [ ! -f "$required" ]; then
    echo "Missing required task file: $required" >&2
    exit 1
  fi
done

EVENTS_JSON="$(printf '%s\n' "${EVENTS[@]}")"
export CHECKPOINT_FILE HANDOFF_FILE PROGRESS_FILE TASK_SLUG STATUS STOP_REASON SUMMARY_TEXT NEXT_STEP NEXT_SLICE EVENTS_JSON

python3 <<'PY'
import json
import os
from datetime import datetime, timezone
from pathlib import Path


def load_json(path: Path) -> dict:
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise SystemExit(f"Expected a JSON object in {path}")
    return data


checkpoint_path = Path(os.environ["CHECKPOINT_FILE"])
handoff_path = Path(os.environ["HANDOFF_FILE"])
progress_path = Path(os.environ["PROGRESS_FILE"])
task_slug = os.environ["TASK_SLUG"]
status = os.environ["STATUS"].strip()
stop_reason = os.environ["STOP_REASON"].strip()
summary_text = os.environ["SUMMARY_TEXT"].strip()
next_step = os.environ["NEXT_STEP"].strip()
next_slice = os.environ["NEXT_SLICE"].strip()
event_lines = [line.strip() for line in os.environ["EVENTS_JSON"].splitlines() if line.strip()]

checkpoint = load_json(checkpoint_path)
current = checkpoint.get("current", {})
if not isinstance(current, dict):
    current = {}
last_run = checkpoint.get("last_run", {})
if not isinstance(last_run, dict):
    last_run = {}
events = last_run.get("events", [])
if not isinstance(events, list):
    events = []
if "slice_completed" not in events:
    events.append("slice_completed")
for event in event_lines:
    if event and event not in events:
        events.append(event)

phase_by_status = {
    "validated": "validated",
    "completed": "validated",
    "blocked": "blocked",
    "waiting_on_decision": "waiting_on_decision",
    "in_progress": "implementation",
    "ready": "planning",
}
stop_reason_by_status = {
    "validated": "milestone_validated",
    "completed": "milestone_validated",
    "blocked": "blocked",
    "waiting_on_decision": "waiting_on_decision",
}

now = datetime.now(timezone.utc)
today = now.strftime("%Y-%m-%d")
now_utc = now.isoformat(timespec="microseconds").replace("+00:00", "Z")

checkpoint["status"] = status
checkpoint["phase"] = phase_by_status.get(status, checkpoint.get("phase", "implementation"))
checkpoint["last_updated"] = today

last_run.update(
    {
        "ended_at": now_utc,
        "stop_reason": stop_reason or stop_reason_by_status.get(status, ""),
        "summary": summary_text or last_run.get("summary", ""),
        "next_step": next_step or last_run.get("next_step", ""),
        "events": events,
    }
)
checkpoint["last_run"] = last_run
checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n")

resume_prompt = ""
handoff_text = handoff_path.read_text()
if "## Resume Prompt" in handoff_text:
    resume_prompt = handoff_text.split("## Resume Prompt", 1)[1].lstrip().strip()

status_label = {
    "validated": "validated",
    "completed": "completed",
    "blocked": "blocked",
    "waiting_on_decision": "waiting on decision",
}.get(status, status)

milestone_id = str(current.get("milestone_id", "")).strip() or "not started"
milestone_title = str(current.get("milestone_title", "")).strip()
milestone_line = milestone_id if milestone_id == "not started" else f"`{milestone_id}` - {milestone_title or milestone_id}"
handoff_lines = [
    "# Handoff",
    "",
    "## Current Status",
    "",
    f"- Status: {status_label}",
    f"- Current milestone: {milestone_line}",
    f"- Next slice: {next_slice or next_step or 'Choose the next dependency-safe slice.'}",
    f"- Stop reason: {stop_reason or stop_reason_by_status.get(status, '')}",
    "",
    "## Resume Prompt",
    "",
    resume_prompt,
    "",
]
handoff_path.write_text("\n".join(handoff_lines))

progress_text = progress_path.read_text().rstrip()
today_header = f"## {today}"
progress_lines = progress_text.splitlines()
entry_lines = [
    f"- Completed `{current.get('milestone_id', '') or 'slice'}` / `{current.get('slice_id', '') or 'slice'}` with status `{status}`.",
]
if summary_text:
    entry_lines.append(f"- Summary: {summary_text}")
if next_step:
    entry_lines.append(f"- Next step: {next_step}")

if today_header in progress_lines:
    index = progress_lines.index(today_header) + 1
    progress_lines[index:index] = [""]
    insert_at = index + 1
    progress_lines[insert_at:insert_at] = entry_lines
    updated_progress = "\n".join(progress_lines).rstrip() + "\n"
else:
    updated_progress = (
        progress_text
        + ("\n\n" if progress_text else "")
        + today_header
        + "\n\n"
        + "\n".join(entry_lines)
        + "\n"
    )
progress_path.write_text(updated_progress)

print(f"Completed task: {task_slug}")
print(f"  status: {status}")
print(f"  stop_reason: {stop_reason or stop_reason_by_status.get(status, '')}")
print(f"  next_step: {next_step or '(none)'}")
PY

HEARTBEAT_STATE="$STATE_OVERRIDE"
if [ -z "$HEARTBEAT_STATE" ]; then
  case "$STATUS" in
    completed)
      HEARTBEAT_STATE="completed"
      ;;
    blocked)
      HEARTBEAT_STATE="blocked"
      ;;
    waiting_on_decision)
      HEARTBEAT_STATE="waiting_on_decision"
      ;;
    *)
      HEARTBEAT_STATE="idle"
      ;;
  esac
fi

"$TOUCH_HEARTBEAT_SCRIPT" --root "$ROOT_DIR" --state "$HEARTBEAT_STATE" --source "complete_slice.sh" --summary "$SUMMARY_TEXT" "$TASK_SLUG" >/dev/null

if [ "$REFRESH_REGISTRY" = true ]; then
  "$REFRESH_REGISTRY_SCRIPT" --root "$ROOT_DIR" >/dev/null
fi
