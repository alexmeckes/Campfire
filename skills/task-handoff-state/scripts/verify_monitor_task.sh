#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
COMPLETE_SLICE_SCRIPT="$SKILL_DIR/scripts/complete_slice.sh"
MONITOR_SCRIPT="$SKILL_DIR/scripts/monitor_task.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_contains() {
  local path="$1"
  local pattern="$2"
  if ! /usr/bin/grep -Fq -- "$pattern" "$path"; then
    fail "Expected pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$INIT_SCRIPT" "$START_SLICE_SCRIPT" "$COMPLETE_SLICE_SCRIPT" "$MONITOR_SCRIPT" "$0"

echo "== Monitor task flow =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_monitor_healthy.json /tmp/campfire_monitor_blocked.json /tmp/campfire_monitor_waiting.json /tmp/campfire_monitor_stale.json /tmp/campfire_monitor_stale_text.out' EXIT

cat >"$TEMP_WORKSPACE/campfire.toml" <<'EOF'
version = 1
project_name = "Monitor Task Verifier"
default_task_root = ".tasks"
EOF

HEALTHY_SLUG="verify-monitor-healthy"
BLOCKED_SLUG="verify-monitor-blocked"
WAITING_SLUG="verify-monitor-waiting"
STALE_SLUG="verify-monitor-stale"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$HEALTHY_SLUG" "verify monitor healthy state" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --milestone-id "milestone-001" --milestone-title "Healthy active slice" --slice-id "healthy-slice" --slice-title "Keep the task healthy" "$HEALTHY_SLUG" >/dev/null
"$MONITOR_SCRIPT" --root "$TEMP_WORKSPACE" --json "$HEALTHY_SLUG" >/tmp/campfire_monitor_healthy.json

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$BLOCKED_SLUG" "verify monitor blocked state" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --milestone-id "milestone-001" --milestone-title "Blocked slice" --slice-id "blocked-slice" --slice-title "Enter blocked state" "$BLOCKED_SLUG" >/dev/null
"$COMPLETE_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --status blocked --summary "The task is blocked for monitor verification." --next-step "Wait for recovery." "$BLOCKED_SLUG" >/dev/null
"$MONITOR_SCRIPT" --root "$TEMP_WORKSPACE" --json "$BLOCKED_SLUG" >/tmp/campfire_monitor_blocked.json

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$WAITING_SLUG" "verify monitor waiting state" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --milestone-id "milestone-001" --milestone-title "Decision slice" --slice-id "decision-slice" --slice-title "Enter decision stop" "$WAITING_SLUG" >/dev/null
"$COMPLETE_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --status waiting_on_decision --summary "A real decision boundary is pending." --next-step "Wait for explicit operator input." "$WAITING_SLUG" >/dev/null
"$MONITOR_SCRIPT" --root "$TEMP_WORKSPACE" --json "$WAITING_SLUG" >/tmp/campfire_monitor_waiting.json

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$STALE_SLUG" "verify monitor stale heartbeat" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --milestone-id "milestone-001" --milestone-title "Stale heartbeat slice" --slice-id "stale-slice" --slice-title "Let the heartbeat go stale" "$STALE_SLUG" >/dev/null

python3 - "$TEMP_WORKSPACE/.tasks/$STALE_SLUG/heartbeat.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text())
payload["last_seen_at"] = "2026-03-18T00:00:00Z"
path.write_text(json.dumps(payload, indent=2) + "\n")
PY

"$MONITOR_SCRIPT" --root "$TEMP_WORKSPACE" --json --write-alert --stale-heartbeat-minutes 5 "$STALE_SLUG" >/tmp/campfire_monitor_stale.json
"$MONITOR_SCRIPT" --root "$TEMP_WORKSPACE" --stale-heartbeat-minutes 5 "$STALE_SLUG" >/tmp/campfire_monitor_stale_text.out

python3 - "$TEMP_WORKSPACE" <<'PY'
import json
import sys
from pathlib import Path

workspace = Path(sys.argv[1]).resolve()

healthy = json.loads(Path("/tmp/campfire_monitor_healthy.json").read_text())
if healthy.get("recommended_action") != "allow":
    raise SystemExit("healthy task should allow")
if healthy.get("severity") != "low":
    raise SystemExit("healthy task severity mismatch")
if "healthy_active_slice" not in healthy.get("reason_codes", []):
    raise SystemExit("healthy reason code mismatch")

blocked = json.loads(Path("/tmp/campfire_monitor_blocked.json").read_text())
if blocked.get("recommended_action") != "pause":
    raise SystemExit("blocked task should pause")
if blocked.get("severity") != "high":
    raise SystemExit("blocked task severity mismatch")
if "blocked" not in blocked.get("reason_codes", []):
    raise SystemExit("blocked reason code mismatch")

waiting = json.loads(Path("/tmp/campfire_monitor_waiting.json").read_text())
if waiting.get("recommended_action") != "pause":
    raise SystemExit("waiting task should pause")
if waiting.get("severity") != "high":
    raise SystemExit("waiting task severity mismatch")
if "waiting_on_decision" not in waiting.get("reason_codes", []):
    raise SystemExit("waiting reason code mismatch")

stale = json.loads(Path("/tmp/campfire_monitor_stale.json").read_text())
if stale.get("recommended_action") != "doctor":
    raise SystemExit("stale task should recommend doctor")
if stale.get("severity") != "medium":
    raise SystemExit("stale task severity mismatch")
if "stale_heartbeat" not in stale.get("reason_codes", []):
    raise SystemExit("stale reason code mismatch")
if not stale.get("alert_path"):
    raise SystemExit("stale task should write alert path")
alert_path = Path(stale["alert_path"])
if not alert_path.exists():
    raise SystemExit("monitor alert path missing")
if workspace.as_posix() not in stale.get("task_dir", ""):
    raise SystemExit("task dir mismatch")

print("Monitor task state verified.")
PY

expect_contains /tmp/campfire_monitor_stale_text.out 'recommended_action: doctor'
expect_contains /tmp/campfire_monitor_stale_text.out 'suggested_helper: ./scripts/doctor_task.sh verify-monitor-stale'

echo "PASS: Monitor task verification completed."
