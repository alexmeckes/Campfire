#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MONITOR_SCRIPT="${MONITOR_SCRIPT:-$SCRIPT_DIR/monitor_task.sh}"
INTERVAL_SECONDS=30
STALE_HEARTBEAT_MINUTES=20
TASK_SLUG=""

usage() {
  cat <<'EOF'
Usage:
  monitor_task_loop.sh [--root /path/to/workspace] [--interval-seconds N] [--stale-heartbeat-minutes N] <task-slug>

Notes:
  - Runs continuously until interrupted.
  - Writes extension-local snapshots under .campfire/monitoring/latest/.
  - Writes the latest compact state signature under .campfire/monitoring/state/.
  - Emits alert files only when the monitor state changes into a non-allow action.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --interval-seconds)
      INTERVAL_SECONDS="$2"
      shift 2
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

if ! [[ "$INTERVAL_SECONDS" =~ ^[0-9]+$ ]] || [ "$INTERVAL_SECONDS" -le 0 ]; then
  echo "--interval-seconds must be a positive integer" >&2
  exit 1
fi

if ! [[ "$STALE_HEARTBEAT_MINUTES" =~ ^[0-9]+$ ]]; then
  echo "--stale-heartbeat-minutes must be a non-negative integer" >&2
  exit 1
fi

if [ ! -x "$MONITOR_SCRIPT" ]; then
  echo "Monitor helper not found or not executable: $MONITOR_SCRIPT" >&2
  exit 1
fi

TASK_SLUG="$1"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"

STATE_DIR="$ROOT_DIR/.campfire/monitoring/state"
LATEST_DIR="$ROOT_DIR/.campfire/monitoring/latest"
ALERTS_DIR="$ROOT_DIR/.campfire/monitoring/alerts"

mkdir -p "$STATE_DIR" "$LATEST_DIR" "$ALERTS_DIR"

STATE_FILE="$STATE_DIR/$TASK_SLUG.json"
LATEST_FILE="$LATEST_DIR/$TASK_SLUG.json"
previous_signature=""

if [ -f "$STATE_FILE" ]; then
  previous_signature="$(python3 - "$STATE_FILE" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception:
    print("")
    raise SystemExit(0)

print(str(data.get("signature", "")))
PY
)"
fi

echo "monitor_loop: task=$TASK_SLUG interval=${INTERVAL_SECONDS}s stale_threshold=${STALE_HEARTBEAT_MINUTES}m"

while true; do
  payload="$("$MONITOR_SCRIPT" --root "$ROOT_DIR" --json --stale-heartbeat-minutes "$STALE_HEARTBEAT_MINUTES" "$TASK_SLUG")"
  printf '%s\n' "$payload" > "$LATEST_FILE"

  analysis="$(python3 - <<'PY' "$payload"
import hashlib
import json
import sys
from datetime import datetime, timezone

payload = json.loads(sys.argv[1])
current = payload.get("current", {})
signature_fields = {
    "status": payload.get("status", ""),
    "phase": payload.get("phase", ""),
    "milestone_id": current.get("milestone_id", ""),
    "slice_id": current.get("slice_id", ""),
    "recommended_action": payload.get("recommended_action", ""),
    "severity": payload.get("severity", ""),
    "reason_codes": payload.get("reason_codes", []),
    "last_stop_reason": payload.get("last_stop_reason", ""),
}
summary = {
    "signature": hashlib.sha256(json.dumps(signature_fields, sort_keys=True).encode("utf-8")).hexdigest(),
    "recorded_at": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
    "recommended_action": payload.get("recommended_action", ""),
    "severity": payload.get("severity", ""),
    "summary": payload.get("summary", ""),
    "status": payload.get("status", ""),
    "phase": payload.get("phase", ""),
    "milestone_id": current.get("milestone_id", ""),
    "slice_id": current.get("slice_id", ""),
}
print(json.dumps(summary))
PY
)"

  signature="$(python3 - <<'PY' "$analysis"
import json
import sys

print(json.loads(sys.argv[1])["signature"])
PY
)"

  if [ "$signature" != "$previous_signature" ]; then
    printf '%s\n' "$analysis" > "$STATE_FILE"

    recommended_action="$(python3 - <<'PY' "$analysis"
import json
import sys

print(json.loads(sys.argv[1])["recommended_action"])
PY
)"
    severity="$(python3 - <<'PY' "$analysis"
import json
import sys

print(json.loads(sys.argv[1])["severity"])
PY
)"
    summary="$(python3 - <<'PY' "$analysis"
import json
import sys

print(json.loads(sys.argv[1])["summary"])
PY
)"
    monitor_status="$(python3 - <<'PY' "$analysis"
import json
import sys

print(json.loads(sys.argv[1])["status"])
PY
)"
    monitor_phase="$(python3 - <<'PY' "$analysis"
import json
import sys

print(json.loads(sys.argv[1])["phase"])
PY
)"
    milestone_id="$(python3 - <<'PY' "$analysis"
import json
import sys

print(json.loads(sys.argv[1])["milestone_id"])
PY
)"
    slice_id="$(python3 - <<'PY' "$analysis"
import json
import sys

print(json.loads(sys.argv[1])["slice_id"])
PY
)"

    echo "monitor_change: status=$monitor_status phase=$monitor_phase milestone=$milestone_id slice=$slice_id action=$recommended_action severity=$severity summary=$summary"

    if [ "$recommended_action" != "allow" ]; then
      "$MONITOR_SCRIPT" --root "$ROOT_DIR" --json --write-alert --stale-heartbeat-minutes "$STALE_HEARTBEAT_MINUTES" "$TASK_SLUG" >/dev/null
      echo "monitor_alert: action=$recommended_action severity=$severity"
    fi

    previous_signature="$signature"
  fi

  sleep "$INTERVAL_SECONDS"
done
