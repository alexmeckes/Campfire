#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_waiting_on_decision.sh"

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

echo "== Rolling waiting-on-decision simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_decision_init.out /tmp/campfire_decision_resume.out' EXIT
TASK_SLUG="verify-waiting-on-decision"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify rolling waiting-on-decision handling" >/tmp/campfire_decision_init.out

expect_file "$TASK_DIR/checkpoints.json"
expect_file "$TASK_DIR/handoff.md"
expect_file "$TASK_DIR/progress.md"
expect_file "$TASK_DIR/artifacts.json"

cat > "$TASK_DIR/findings/decision-boundary-note.md" <<'EOF'
# decision boundary note

- The run reached a real decision boundary before milestone-002 could continue safely.
- The unresolved choice is whether the next slice should prioritize a live-thread resume flow or a background-task resume flow.
- The queued backlog remains intact, but the next run must wait for that decision instead of guessing.
EOF

cat >> "$TASK_DIR/progress.md" <<'EOF'

## 2026-03-14 waiting-on-decision

- Changed: simulated a rolling run that paused at a real decision boundary instead of guessing past it.
- Validation: recorded the unresolved decision in `findings/decision-boundary-note.md` and preserved the queued backlog in `checkpoints.json`.
- Blockers: waiting on a product decision about which resume flow should be demonstrated next.
- Next slice: wait for the decision boundary to clear, then resume milestone-002.
EOF

cat > "$TASK_DIR/handoff.md" <<'EOF'
# Handoff

## Current Status

- Status: waiting_on_decision
- Current milestone: milestone-002 - Pause at decision boundary
- Next slice: wait for a decision on the next resume flow before continuing milestone-002
- Stop reason: waiting_on_decision

## Resume Prompt

Use $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue this rolling task from `.autonomous/verify-waiting-on-decision/` after the decision boundary is resolved.
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
checkpoint["status"] = "waiting_on_decision"
checkpoint["phase"] = "execution"
checkpoint["current"] = {
    "milestone_id": "milestone-002",
    "milestone_title": "Pause at decision boundary",
    "slice_id": "slice-004",
    "slice_title": "Wait for the product decision before resuming milestone-002",
    "acceptance_criteria": [
        "The unresolved decision is recorded in task state",
        "The active milestone remains intact while waiting",
        "Queued milestones are preserved for the next run"
    ],
    "dependencies": [
        "findings/decision-boundary-note.md",
        "artifacts.json"
    ],
}
checkpoint["execution"] = {
    "mode": "rolling",
    "auto_advance": True,
    "planning_slice_minutes": 10,
    "runtime_budget_minutes": 60,
    "max_milestones_per_run": 3,
    "continue_until": ["blocked", "waiting_on_decision", "budget_limit"],
    "queued_milestones": [
        {
            "milestone_id": "milestone-003",
            "milestone_title": "Resume after the decision is made"
        }
    ],
    "notes": "The rolling run paused at a real decision boundary; do not consume the queued backlog until the decision is resolved."
}
checkpoint["blocker"] = {
    "status": "active",
    "type": "decision_boundary",
    "summary": "Need a decision on whether the next demonstrated resume flow should focus on live-thread or background-task behavior.",
    "attempts": 1,
    "next_action": "Wait for the decision, then resume milestone-002 without reframing the queued backlog.",
}
checkpoint["last_run"] = {
    "started_at": "2026-03-14T21:00:00Z",
    "ended_at": "2026-03-14T21:20:00Z",
    "stop_reason": "waiting_on_decision",
    "summary": "The rolling run stopped at a real decision boundary and preserved the queued backlog for later resumption.",
    "next_step": "Wait for the decision on the next resume flow, then continue milestone-002."
}
checkpoint["validation"] = [
    {
        "type": "plan_review",
        "result": "pass",
        "command": "review findings/decision-boundary-note.md",
        "artifact": "findings/decision-boundary-note.md",
        "summary": "The decision note proves the unresolved choice and preserved queued backlog were recorded explicitly."
    }
]
checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n")

artifacts = json.loads(artifacts_path.read_text())
artifacts["artifacts"] = [
    {
        "path": "findings/decision-boundary-note.md",
        "type": "planning_note",
        "milestone_id": "milestone-002",
        "reason": "Documents the unresolved decision boundary that paused the rolling run."
    }
]
artifacts_path.write_text(json.dumps(artifacts, indent=2) + "\n")
PY

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_decision_resume.out

expect_contains "$TASK_DIR/checkpoints.json" '"status": "waiting_on_decision"'
expect_contains "$TASK_DIR/checkpoints.json" '"stop_reason": "waiting_on_decision"'
expect_contains "$TASK_DIR/checkpoints.json" '"type": "decision_boundary"'
expect_contains "$TASK_DIR/handoff.md" 'Stop reason: waiting_on_decision'
expect_contains "$TASK_DIR/artifacts.json" '"path": "findings/decision-boundary-note.md"'
expect_contains /tmp/campfire_decision_resume.out 'mode: rolling'
expect_contains /tmp/campfire_decision_resume.out 'waiting_on_decision'
expect_contains /tmp/campfire_decision_resume.out 'decision_boundary'
expect_contains /tmp/campfire_decision_resume.out 'milestone-003: Resume after the decision is made'

echo "PASS: Rolling waiting-on-decision verification completed."
