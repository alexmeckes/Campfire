#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_HELPER="${SQL_HELPER:-$SCRIPT_DIR/campfire_sql.py}"
TASK_SLUG=""
JSON_MODE=false
WRITE_ALERT=false
STALE_HEARTBEAT_MINUTES=20

usage() {
  cat <<'EOF'
Usage:
  monitor_task.sh [--root /path/to/workspace] [--json] [--write-alert] [--stale-heartbeat-minutes N] <task-slug>
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --json)
      JSON_MODE=true
      shift
      ;;
    --write-alert)
      WRITE_ALERT=true
      shift
      ;;
    --stale-heartbeat-minutes)
      STALE_HEARTBEAT_MINUTES="$2"
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

if ! [[ "$STALE_HEARTBEAT_MINUTES" =~ ^[0-9]+$ ]]; then
  echo "--stale-heartbeat-minutes must be a non-negative integer" >&2
  exit 1
fi

TASK_ROOT="$(python3 "$SQL_HELPER" show-project --root "$ROOT_DIR" --field task_root)"
TASK_DIR="$ROOT_DIR/$TASK_ROOT/$TASK_SLUG"
TASK_CONTEXT_FILE="$TASK_DIR/task_context.json"
CHECKPOINT_FILE="$TASK_DIR/checkpoints.json"
HEARTBEAT_FILE="$TASK_DIR/heartbeat.json"
ALERTS_DIR="$ROOT_DIR/.campfire/monitoring/alerts"

if [ ! -d "$TASK_DIR" ]; then
  echo "Task not found: $TASK_DIR" >&2
  exit 1
fi

export ROOT_DIR TASK_SLUG TASK_DIR TASK_CONTEXT_FILE CHECKPOINT_FILE HEARTBEAT_FILE ALERTS_DIR JSON_MODE WRITE_ALERT STALE_HEARTBEAT_MINUTES

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
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def parse_timestamp(value: str) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00"))
    except Exception:
        return None


root_dir = Path(os.environ["ROOT_DIR"]).resolve()
task_slug = os.environ["TASK_SLUG"]
task_dir = Path(os.environ["TASK_DIR"]).resolve()
task_context = load_json(Path(os.environ["TASK_CONTEXT_FILE"]))
checkpoint = load_json(Path(os.environ["CHECKPOINT_FILE"]))
heartbeat = load_json(Path(os.environ["HEARTBEAT_FILE"]))
alerts_dir = Path(os.environ["ALERTS_DIR"])
json_mode = os.environ["JSON_MODE"].strip().lower() == "true"
write_alert = os.environ["WRITE_ALERT"].strip().lower() == "true"
stale_minutes = int(os.environ["STALE_HEARTBEAT_MINUTES"])

status = str(task_context.get("status") or checkpoint.get("status") or "").strip()
phase = str(task_context.get("phase") or checkpoint.get("phase") or "").strip()
current = task_context.get("current")
if not isinstance(current, dict):
    current = checkpoint.get("current", {})
if not isinstance(current, dict):
    current = {}
last_run = task_context.get("last_run")
if not isinstance(last_run, dict):
    last_run = checkpoint.get("last_run", {})
if not isinstance(last_run, dict):
    last_run = {}

heartbeat_state = str(heartbeat.get("state") or (task_context.get("heartbeat", {}) or {}).get("state") or "").strip()
heartbeat_last_seen = str(heartbeat.get("last_seen_at") or (task_context.get("heartbeat", {}) or {}).get("last_seen_at") or "").strip()
heartbeat_dt = parse_timestamp(heartbeat_last_seen)
now = datetime.now(timezone.utc)
heartbeat_age_minutes = None
if heartbeat_dt is not None:
    heartbeat_age_minutes = max(0.0, (now - heartbeat_dt).total_seconds() / 60.0)

reason_codes: list[str] = []
severity = "low"
recommended_action = "allow"
summary = "Task appears healthy."
suggested_helper = ""
details: list[str] = []

if status == "waiting_on_decision" or phase == "waiting_on_decision":
    reason_codes.append("waiting_on_decision")
    severity = "high"
    recommended_action = "pause"
    summary = "Task is waiting on a real decision boundary."
    details.append("Do not continue work past the unresolved decision boundary.")
elif status == "blocked" or phase == "blocked":
    reason_codes.append("blocked")
    severity = "high"
    recommended_action = "pause"
    summary = "Task is blocked and should not continue automatically."
    suggested_helper = f"./scripts/doctor_task.sh {task_slug}"
    details.append("Review blocker state before attempting recovery.")
elif status == "in_progress":
    if not str(current.get("slice_id", "")).strip():
        reason_codes.append("missing_active_slice")
        severity = "high"
        recommended_action = "doctor"
        summary = "Task is marked in progress but has no active slice."
        suggested_helper = f"./scripts/doctor_task.sh {task_slug}"
        details.append("This is likely state drift or an incomplete slice transition.")
    elif heartbeat_age_minutes is None:
        reason_codes.append("missing_heartbeat")
        severity = "medium"
        recommended_action = "doctor"
        summary = "Active task has no readable heartbeat timestamp."
        suggested_helper = f"./scripts/doctor_task.sh {task_slug}"
        details.append("Refresh or repair task state before continuing unattended work.")
    elif heartbeat_age_minutes > stale_minutes:
        reason_codes.append("stale_heartbeat")
        severity = "medium"
        recommended_action = "doctor"
        summary = "Active task heartbeat is stale."
        suggested_helper = f"./scripts/doctor_task.sh {task_slug}"
        details.append(
            f"Last heartbeat is about {heartbeat_age_minutes:.1f} minutes old, beyond the {stale_minutes}-minute threshold."
        )
    else:
        reason_codes.append("healthy_active_slice")
        details.append("Active slice and heartbeat look healthy.")
else:
    reason_codes.append("stable_terminal_or_idle_state")
    details.append("No intervention is needed from the monitor.")

payload = {
    "task_slug": task_slug,
    "task_dir": str(task_dir),
    "status": status,
    "phase": phase,
    "current": {
        "milestone_id": str(current.get("milestone_id", "")).strip(),
        "milestone_title": str(current.get("milestone_title", "")).strip(),
        "slice_id": str(current.get("slice_id", "")).strip(),
        "slice_title": str(current.get("slice_title", "")).strip(),
    },
    "heartbeat_state": heartbeat_state,
    "heartbeat_last_seen_at": heartbeat_last_seen,
    "heartbeat_age_minutes": None if heartbeat_age_minutes is None else round(heartbeat_age_minutes, 2),
    "recommended_action": recommended_action,
    "severity": severity,
    "summary": summary,
    "reason_codes": reason_codes,
    "suggested_helper": suggested_helper,
    "details": details,
    "last_stop_reason": str(last_run.get("stop_reason", "")).strip(),
}

alert_path = ""
if write_alert:
    alerts_dir.mkdir(parents=True, exist_ok=True)
    timestamp = now.strftime("%Y%m%dT%H%M%SZ")
    alert_path = alerts_dir / f"{timestamp}-{task_slug}.json"
    alert_payload = {
        "task_slug": task_slug,
        "severity": severity,
        "category": reason_codes[0] if reason_codes else "monitor_advisory",
        "summary": summary,
        "recommended_action": recommended_action,
        "suggested_helper": suggested_helper,
        "recorded_at": now.isoformat(timespec="seconds").replace("+00:00", "Z"),
    }
    alert_path.write_text(json.dumps(alert_payload, indent=2) + "\n")
    payload["alert_path"] = str(alert_path)

if json_mode:
    print(json.dumps(payload, indent=2))
else:
    print(f"task: {task_slug}")
    print(f"status: {status or 'unknown'}")
    if payload["current"]["milestone_id"]:
        print(f"milestone: {payload['current']['milestone_id']} - {payload['current']['milestone_title'] or payload['current']['milestone_id']}")
    if payload["current"]["slice_id"]:
        print(f"slice: {payload['current']['slice_id']} - {payload['current']['slice_title'] or payload['current']['slice_id']}")
    print(f"recommended_action: {recommended_action}")
    print(f"severity: {severity}")
    print(f"summary: {summary}")
    if heartbeat_last_seen:
        print(f"heartbeat_last_seen_at: {heartbeat_last_seen}")
    if heartbeat_age_minutes is not None:
        print(f"heartbeat_age_minutes: {heartbeat_age_minutes:.2f}")
    if suggested_helper:
        print(f"suggested_helper: {suggested_helper}")
    if alert_path:
        print(f"alert_path: {alert_path}")
    if details:
        print("details:")
        for item in details:
            print(f"  - {item}")
PY
