#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
COMPLETE_SLICE_SCRIPT="$SKILL_DIR/scripts/complete_slice.sh"
MONITOR_SCRIPT="$SKILL_DIR/scripts/monitor_task.sh"
LOOP_SCRIPT="$SKILL_DIR/scripts/monitor_task_loop.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_file() {
  local path="$1"
  [ -e "$path" ] || fail "Missing required path: $path"
}

expect_contains() {
  local path="$1"
  local pattern="$2"
  if ! /usr/bin/grep -Fq -- "$pattern" "$path"; then
    fail "Expected pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$INIT_SCRIPT" "$START_SLICE_SCRIPT" "$COMPLETE_SLICE_SCRIPT" "$MONITOR_SCRIPT" "$LOOP_SCRIPT" "$0"

echo "== Monitor loop flow =="
TEMP_WORKSPACE="$(mktemp -d)"
LOOP_PID=""
trap 'if [ -n "${LOOP_PID:-}" ]; then kill "$LOOP_PID" >/dev/null 2>&1 || true; wait "$LOOP_PID" >/dev/null 2>&1 || true; fi; rm -rf "$TEMP_WORKSPACE" /tmp/campfire_monitor_loop.out /tmp/campfire_monitor_loop_latest.json /tmp/campfire_monitor_loop_state.json' EXIT

cat >"$TEMP_WORKSPACE/campfire.toml" <<'EOF'
version = 1
project_name = "Monitor Loop Verifier"
default_task_root = ".tasks"
EOF

TASK_SLUG="verify-monitor-loop"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify monitor loop state transitions" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --milestone-id "milestone-001" --milestone-title "Healthy active slice" --slice-id "healthy-slice" --slice-title "Keep the loop healthy" "$TASK_SLUG" >/dev/null

"$LOOP_SCRIPT" --root "$TEMP_WORKSPACE" --interval-seconds 1 --stale-heartbeat-minutes 5 "$TASK_SLUG" >/tmp/campfire_monitor_loop.out 2>&1 &
LOOP_PID="$!"

sleep 2

LATEST_FILE="$TEMP_WORKSPACE/.campfire/monitoring/latest/$TASK_SLUG.json"
STATE_FILE="$TEMP_WORKSPACE/.campfire/monitoring/state/$TASK_SLUG.json"
ALERTS_DIR="$TEMP_WORKSPACE/.campfire/monitoring/alerts"

expect_file "$LATEST_FILE"
expect_file "$STATE_FILE"
expect_contains /tmp/campfire_monitor_loop.out "monitor_loop: task=$TASK_SLUG"
expect_contains /tmp/campfire_monitor_loop.out 'monitor_change:'

"$COMPLETE_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --status waiting_on_decision --summary "Pause the run for an explicit decision." --next-step "Wait for operator input." "$TASK_SLUG" >/dev/null

sleep 2

kill "$LOOP_PID" >/dev/null 2>&1 || true
wait "$LOOP_PID" >/dev/null 2>&1 || true
LOOP_PID=""

cp "$LATEST_FILE" /tmp/campfire_monitor_loop_latest.json
cp "$STATE_FILE" /tmp/campfire_monitor_loop_state.json

python3 - "$ALERTS_DIR" <<'PY'
import json
import sys
from pathlib import Path

latest = json.loads(Path("/tmp/campfire_monitor_loop_latest.json").read_text())
state = json.loads(Path("/tmp/campfire_monitor_loop_state.json").read_text())
alerts_dir = Path(sys.argv[1])
alerts = sorted(alerts_dir.glob("*.json"))

if latest.get("recommended_action") != "pause":
    raise SystemExit("loop latest payload should end in pause")
if state.get("recommended_action") != "pause":
    raise SystemExit("loop state payload should end in pause")
if latest.get("status") != "waiting_on_decision":
    raise SystemExit("loop latest status mismatch")
if state.get("status") != "waiting_on_decision":
    raise SystemExit("loop state status mismatch")
if not alerts:
    raise SystemExit("loop should write at least one alert on non-allow state")
PY

expect_contains /tmp/campfire_monitor_loop.out 'monitor_alert: action=pause severity=high'

echo "PASS: Monitor loop verification completed."
