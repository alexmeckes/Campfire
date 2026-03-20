#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_rolling_execution.sh"

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
zsh -n "$INIT_SCRIPT" "$RESUME_SCRIPT" "$SELF_SCRIPT"

echo "== Rolling execution simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_rolling_init.out /tmp/campfire_rolling_resume.out' EXIT
TASK_SLUG="verify-rolling-execution"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify rolling execution handling" >/tmp/campfire_rolling_init.out

expect_file "$TASK_DIR/plan.md"
expect_file "$TASK_DIR/handoff.md"
expect_file "$TASK_DIR/checkpoints.json"
expect_file "$TASK_DIR/artifacts.json"

cat > "$TASK_DIR/findings/rolling-transition.md" <<'EOF'
# rolling transition

- Validated milestone-001.
- Auto-advanced into milestone-002 because rolling execution is enabled.
- The run then paused for a manual checkpoint while milestone-002 remained active.
- Remaining queued milestone: milestone-003.
EOF

cat >> "$TASK_DIR/progress.md" <<'EOF'

## 2026-03-14 rolling-transition

- Changed: simulated a rolling run that validated milestone-001 and auto-advanced into milestone-002.
- Changed: recorded the auto-advance as a run event while leaving the terminal stop reason as a manual pause.
- Validation: recorded the transition in `findings/rolling-transition.md`.
- Blockers: none.
- Next slice: implement milestone-002 while the runtime budget remains.
EOF

cat > "$TASK_DIR/handoff.md" <<'EOF'
# Handoff

## Current Status

- Status: ready
- Current milestone: milestone-002 - Continue after auto-advance
- Next slice: implement milestone-002 while the runtime budget remains
- Stop reason: manual_pause

## Resume Prompt

Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue this rolling task from `.autonomous/verify-rolling-execution/` and keep going until a configured run limit or real blocker appears.
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
checkpoint["status"] = "ready"
checkpoint["phase"] = "execution"
checkpoint["current"] = {
    "milestone_id": "milestone-002",
    "milestone_title": "Continue after auto-advance",
    "slice_id": "slice-003",
    "slice_title": "Implement milestone-002 while budget remains",
    "acceptance_criteria": [
        "Rolling mode keeps a queued backlog",
        "A validated milestone can auto-advance into the next one",
    ],
    "dependencies": [
        "findings/rolling-transition.md",
        "artifacts.json",
    ],
}
checkpoint["execution"] = {
    "mode": "rolling",
    "auto_advance": True,
    "planning_slice_minutes": 10,
    "runtime_budget_minutes": 120,
    "max_milestones_per_run": 3,
    "continue_until": ["blocked", "waiting_on_decision", "budget_limit"],
    "queued_milestones": [
        {
            "milestone_id": "milestone-003",
            "milestone_title": "Wrap the rolling run with evaluation evidence"
        }
    ],
    "notes": "Milestone-001 already validated in this simulated run; continue until a run limit or blocker appears.",
}
checkpoint["last_run"] = {
    "started_at": "2026-03-14T19:00:00Z",
    "ended_at": "2026-03-14T19:05:00Z",
    "stop_reason": "manual_pause",
    "summary": "Validated milestone-001, auto-advanced directly into milestone-002, then paused with the remaining queue preserved.",
    "next_step": "Implement milestone-002 while the runtime budget remains.",
    "events": ["auto_advanced"]
}
checkpoint["validation"] = [
    {
        "type": "milestone_evaluation",
        "result": "pass",
        "command": "review findings/rolling-transition.md",
        "artifact": "findings/rolling-transition.md",
        "summary": "Rolling transition note proves the task advanced after validation."
    }
]
checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n")

artifacts = json.loads(artifacts_path.read_text())
artifacts["artifacts"] = [
    {
        "path": "findings/rolling-transition.md",
        "type": "planning_note",
        "milestone_id": "milestone-002",
        "reason": "Documents the auto-advance from one validated milestone into the next queued milestone."
    }
]
artifacts_path.write_text(json.dumps(artifacts, indent=2) + "\n")
PY

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_rolling_resume.out

expect_contains "$TASK_DIR/checkpoints.json" '"mode": "rolling"'
expect_contains "$TASK_DIR/checkpoints.json" '"stop_reason": "manual_pause"'
expect_contains "$TASK_DIR/checkpoints.json" '"events": ['
expect_contains "$TASK_DIR/checkpoints.json" '"auto_advanced"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_title": "Continue after auto-advance"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_id": "milestone-003"'
expect_contains "$TASK_DIR/handoff.md" 'Current milestone: milestone-002 - Continue after auto-advance'
expect_contains "$TASK_DIR/handoff.md" 'Stop reason: manual_pause'
expect_contains /tmp/campfire_rolling_resume.out 'mode: rolling'
expect_contains /tmp/campfire_rolling_resume.out 'auto_advance: True'
expect_contains /tmp/campfire_rolling_resume.out 'queued_milestones:'
expect_contains /tmp/campfire_rolling_resume.out 'stop_reason: manual_pause'
expect_contains /tmp/campfire_rolling_resume.out 'events:'
expect_contains /tmp/campfire_rolling_resume.out 'auto_advanced'
expect_contains /tmp/campfire_rolling_resume.out 'auto-advance through queued milestones'
expect_contains /tmp/campfire_rolling_resume.out 'Suggested monitor sidecar:'
expect_contains /tmp/campfire_rolling_resume.out "./scripts/monitor_task_loop.sh $TASK_SLUG"

echo "PASS: Rolling execution verification completed."
