#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_blocked_retry.sh"

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
  if ! /usr/bin/grep -q "$pattern" "$path"; then
    fail "Expected pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$INIT_SCRIPT" "$RESUME_SCRIPT" "$SELF_SCRIPT"

echo "== Blocked and retry simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_blocked_init.out /tmp/campfire_blocked_resume.out' EXIT
TASK_SLUG="verify-blocked-retry"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify blocked and retry handling" >/tmp/campfire_blocked_init.out

expect_file "$TASK_DIR/checkpoints.json"
expect_file "$TASK_DIR/handoff.md"
expect_file "$TASK_DIR/progress.md"
expect_file "$TASK_DIR/artifacts.json"

cat >> "$TASK_DIR/progress.md" <<'EOF'

## 2026-03-14 blocker

- Changed: simulated a blocked task after two retry attempts.
- Validation: both retry attempts failed; escalation state recorded in checkpoints.
- Blockers: missing API credentials for external dependency.
- Next slice: wait for credentials or replace the dependency.
EOF

cat > "$TASK_DIR/handoff.md" <<'EOF'
# Handoff

## Current Status

- Status: blocked
- Current milestone: milestone-002 - unblock external dependency
- Next slice: wait for credentials or replace the dependency
- Stop reason: blocked

## Resume Prompt

Use $long-horizon-worker and $task-handoff-state to continue this task from `.autonomous/verify-blocked-retry/` and either resolve the blocker or stop on the next real escalation boundary.
EOF

export TASK_DIR
python3 <<'PY'
import json
import os
from pathlib import Path

task_dir = Path(os.environ["TASK_DIR"])
checkpoint_path = task_dir / "checkpoints.json"
artifacts_path = task_dir / "artifacts.json"

checkpoint = json.loads(checkpoint_path.read_text())
checkpoint["status"] = "blocked"
checkpoint["phase"] = "execution"
checkpoint["current"] = {
    "milestone_id": "milestone-002",
    "milestone_title": "Unblock external dependency",
    "slice_id": "slice-003",
    "slice_title": "Retry dependency setup and escalate on failure",
    "acceptance_criteria": [
        "Credentials available or dependency removed",
        "Retry state recorded with escalation path",
    ],
    "dependencies": ["runbook.md"],
}
checkpoint["blocker"] = {
    "status": "blocked",
    "type": "missing_credentials",
    "summary": "External dependency requires credentials that are not available in the environment.",
    "attempts": 2,
    "next_action": "Escalate to the user or replace the dependency.",
}
checkpoint["last_run"] = {
    "started_at": "2026-03-14T16:50:00Z",
    "ended_at": "2026-03-14T16:54:00Z",
    "stop_reason": "blocked",
    "summary": "Two retry attempts failed and the task escalated into a blocked state.",
    "next_step": "Wait for credentials or choose an alternative dependency path.",
}
checkpoint["validation"] = [
    {
        "type": "retry_attempt",
        "result": "fail",
        "command": "setup dependency attempt 1",
        "summary": "Attempt 1 failed due to missing credentials.",
    },
    {
        "type": "retry_attempt",
        "result": "fail",
        "command": "setup dependency attempt 2",
        "summary": "Attempt 2 failed due to missing credentials.",
    },
]
checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n")

artifacts = json.loads(artifacts_path.read_text())
artifacts["artifacts"] = [
    {
        "path": "logs/retry-1.log",
        "type": "retry_log",
        "milestone_id": "milestone-002",
        "reason": "Failure evidence for retry attempt 1.",
    },
    {
        "path": "logs/retry-2.log",
        "type": "retry_log",
        "milestone_id": "milestone-002",
        "reason": "Failure evidence for retry attempt 2.",
    },
]
artifacts_path.write_text(json.dumps(artifacts, indent=2) + "\n")
PY

cat > "$TASK_DIR/logs/retry-1.log" <<'EOF'
missing credentials
EOF

cat > "$TASK_DIR/logs/retry-2.log" <<'EOF'
missing credentials
EOF

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_blocked_resume.out

expect_contains "$TASK_DIR/checkpoints.json" '"status": "blocked"'
expect_contains "$TASK_DIR/checkpoints.json" '"attempts": 2'
expect_contains "$TASK_DIR/checkpoints.json" '"stop_reason": "blocked"'
expect_contains "$TASK_DIR/checkpoints.json" '"type": "missing_credentials"'
expect_contains "$TASK_DIR/handoff.md" 'Status: blocked'
expect_contains "$TASK_DIR/handoff.md" 'Stop reason: blocked'
expect_contains "$TASK_DIR/artifacts.json" '"path": "logs/retry-1.log"'
expect_contains /tmp/campfire_blocked_resume.out 'missing_credentials'
expect_contains /tmp/campfire_blocked_resume.out 'attempts'
expect_contains /tmp/campfire_blocked_resume.out 'blocked'

echo "PASS: Blocked and retry verification completed."
