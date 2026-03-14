#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_budget_limit.sh"

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

echo "== Rolling budget-limit simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_budget_init.out /tmp/campfire_budget_resume.out' EXIT
TASK_SLUG="verify-budget-limit"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify rolling budget-limit handling" >/tmp/campfire_budget_init.out

expect_file "$TASK_DIR/checkpoints.json"
expect_file "$TASK_DIR/handoff.md"
expect_file "$TASK_DIR/progress.md"
expect_file "$TASK_DIR/artifacts.json"

cat > "$TASK_DIR/findings/budget-limit-note.md" <<'EOF'
# budget-limit note

- The run reached its configured time budget before milestone-002 finished.
- The current milestone remains active and queued milestone-003 is still preserved.
- The next Codex App run should resume milestone-002 instead of reframing the task.
EOF

cat >> "$TASK_DIR/progress.md" <<'EOF'

## 2026-03-14 budget-limit

- Changed: simulated a rolling run that hit its time budget while milestone-002 still had remaining work.
- Validation: recorded the paused state in `findings/budget-limit-note.md` and preserved the queued backlog in `checkpoints.json`.
- Blockers: none.
- Next slice: resume milestone-002 with the preserved queued backlog in the next run.
EOF

cat > "$TASK_DIR/handoff.md" <<'EOF'
# Handoff

## Current Status

- Status: ready
- Current milestone: milestone-002 - Resume after budget pause
- Next slice: resume milestone-002 with the preserved queued backlog
- Stop reason: budget_limit

## Resume Prompt

Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue this rolling task from `.autonomous/verify-budget-limit/` and keep going until another configured stop condition appears.
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
    "milestone_title": "Resume after budget pause",
    "slice_id": "slice-003",
    "slice_title": "Resume the partially completed milestone-002 work",
    "acceptance_criteria": [
        "The rolling run preserves the active milestone when the budget is exhausted",
        "Queued milestones remain intact after the pause",
        "The next run has a concrete resume target instead of re-framing the task"
    ],
    "dependencies": [
        "findings/budget-limit-note.md",
        "artifacts.json"
    ],
}
checkpoint["execution"] = {
    "mode": "rolling",
    "auto_advance": True,
    "planning_slice_minutes": 10,
    "runtime_budget_minutes": 45,
    "max_milestones_per_run": 3,
    "continue_until": ["blocked", "waiting_on_decision", "budget_limit", "manual_pause"],
    "queued_milestones": [
        {
            "milestone_id": "milestone-003",
            "milestone_title": "Wrap the resumed run with evaluation evidence"
        }
    ],
    "notes": "Milestone-002 paused because the configured budget was exhausted; resume the same milestone before consuming the queued backlog."
}
checkpoint["blocker"] = {
    "status": "none",
    "type": "",
    "summary": "",
    "attempts": 0,
    "next_action": "",
}
checkpoint["last_run"] = {
    "started_at": "2026-03-14T20:00:00Z",
    "ended_at": "2026-03-14T20:45:00Z",
    "stop_reason": "budget_limit",
    "summary": "The rolling run used its configured budget before milestone-002 finished, so the task paused with queued work still intact.",
    "next_step": "Resume milestone-002 with the preserved queued backlog."
}
checkpoint["validation"] = [
    {
        "type": "plan_review",
        "result": "pass",
        "command": "review findings/budget-limit-note.md",
        "artifact": "findings/budget-limit-note.md",
        "summary": "The budget-limit note proves the current milestone and queued backlog were preserved."
    }
]
checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n")

artifacts = json.loads(artifacts_path.read_text())
artifacts["artifacts"] = [
    {
        "path": "findings/budget-limit-note.md",
        "type": "planning_note",
        "milestone_id": "milestone-002",
        "reason": "Documents the paused rolling state after the run hit its budget."
    }
]
artifacts_path.write_text(json.dumps(artifacts, indent=2) + "\n")
PY

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_budget_resume.out

expect_contains "$TASK_DIR/checkpoints.json" '"stop_reason": "budget_limit"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_title": "Resume after budget pause"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_id": "milestone-003"'
expect_contains "$TASK_DIR/handoff.md" 'Stop reason: budget_limit'
expect_contains "$TASK_DIR/artifacts.json" '"path": "findings/budget-limit-note.md"'
expect_contains /tmp/campfire_budget_resume.out 'mode: rolling'
expect_contains /tmp/campfire_budget_resume.out 'runtime_budget_minutes: 45'
expect_contains /tmp/campfire_budget_resume.out 'budget_limit'
expect_contains /tmp/campfire_budget_resume.out 'milestone-003: Wrap the resumed run with evaluation evidence'

echo "PASS: Rolling budget-limit verification completed."
