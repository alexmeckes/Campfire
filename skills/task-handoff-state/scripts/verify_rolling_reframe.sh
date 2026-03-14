#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_rolling_reframe.sh"

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

echo "== Rolling reframe simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_reframe_init.out /tmp/campfire_reframe_resume.out' EXIT
TASK_SLUG="verify-rolling-reframe"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify rolling queue replenishment handling" >/tmp/campfire_reframe_init.out

expect_file "$TASK_DIR/plan.md"
expect_file "$TASK_DIR/handoff.md"
expect_file "$TASK_DIR/checkpoints.json"
expect_file "$TASK_DIR/artifacts.json"

cat > "$TASK_DIR/findings/rolling-reframe.md" <<'EOF'
# rolling reframe

- Queue depth dropped to the configured threshold while budget remained.
- The run spent one bounded planning slice replenishing the queue with milestone-003 and milestone-004.
- Execution continued from milestone-002 instead of stopping just because the prior queue was nearly empty.
- The run then paused for a manual checkpoint with the replenished queue preserved.
EOF

cat >> "$TASK_DIR/progress.md" <<'EOF'

## 2026-03-14 rolling-reframe

- Changed: simulated a rolling run that replenished its own backlog when queue depth dropped below the configured threshold.
- Changed: recorded the bounded reframe as a run event while leaving the terminal stop reason as a manual pause.
- Validation: recorded the replenishment in `findings/rolling-reframe.md` and added new queued milestones to `checkpoints.json`.
- Blockers: none.
- Next slice: continue milestone-002 with the replenished queue still available.
EOF

cat > "$TASK_DIR/handoff.md" <<'EOF'
# Handoff

## Current Status

- Status: ready
- Current milestone: milestone-002 - Continue after queue replenishment
- Next slice: continue milestone-002 while the replenished queue remains available
- Stop reason: manual_pause

## Resume Prompt

Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue this rolling task from `.autonomous/verify-rolling-reframe/`. Keep planning bounded, auto-advance through queued milestones, replenish the queue when policy allows and budget remains, and stop only on a configured run limit or a real blocker.
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
    "milestone_title": "Continue after queue replenishment",
    "slice_id": "slice-004",
    "slice_title": "Keep implementing milestone-002 after the bounded reframe",
    "acceptance_criteria": [
        "The rolling run can replenish its own backlog when queue depth gets low",
        "New queued milestones are recorded without losing the active milestone",
        "The next run has a concrete resume target and preserved future work"
    ],
    "dependencies": [
        "findings/rolling-reframe.md",
        "artifacts.json"
    ],
}
checkpoint["execution"] = {
    "mode": "rolling",
    "auto_advance": True,
    "auto_reframe": True,
    "planning_slice_minutes": 10,
    "runtime_budget_minutes": 120,
    "max_milestones_per_run": 3,
    "reframe_queue_below": 1,
    "target_queue_depth": 3,
    "max_reframes_per_run": 1,
    "continue_until": ["blocked", "waiting_on_decision", "budget_limit", "manual_pause"],
    "queued_milestones": [
        {
            "milestone_id": "milestone-003",
            "milestone_title": "Document the replenished path"
        },
        {
            "milestone_id": "milestone-004",
            "milestone_title": "Wrap the dynamically extended run with evaluation evidence"
        }
    ],
    "notes": "A bounded reframe replenished the queue because budget remained and the queue had dropped to the configured threshold."
}
checkpoint["last_run"] = {
    "started_at": "2026-03-14T22:00:00Z",
    "ended_at": "2026-03-14T22:08:00Z",
    "stop_reason": "manual_pause",
    "summary": "The rolling run replenished its own backlog when queue depth fell to the configured threshold, continued from the same active milestone, and then paused with the replenished queue preserved.",
    "next_step": "Continue milestone-002 with the replenished queue still available.",
    "events": ["auto_reframed"]
}
checkpoint["validation"] = [
    {
        "type": "plan_review",
        "result": "pass",
        "command": "review findings/rolling-reframe.md",
        "artifact": "findings/rolling-reframe.md",
        "summary": "The reframe note proves queue replenishment happened and execution stayed on the active milestone before the run paused."
    }
]
checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n")

artifacts = json.loads(artifacts_path.read_text())
artifacts["artifacts"] = [
    {
        "path": "findings/rolling-reframe.md",
        "type": "planning_note",
        "milestone_id": "milestone-002",
        "reason": "Documents the bounded queue replenishment that let the rolling run keep going."
    }
]
artifacts_path.write_text(json.dumps(artifacts, indent=2) + "\n")
PY

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_reframe_resume.out

expect_contains "$TASK_DIR/checkpoints.json" '"auto_reframe": true'
expect_contains "$TASK_DIR/checkpoints.json" '"reframe_queue_below": 1'
expect_contains "$TASK_DIR/checkpoints.json" '"target_queue_depth": 3'
expect_contains "$TASK_DIR/checkpoints.json" '"max_reframes_per_run": 1'
expect_contains "$TASK_DIR/checkpoints.json" '"stop_reason": "manual_pause"'
expect_contains "$TASK_DIR/checkpoints.json" '"events": ['
expect_contains "$TASK_DIR/checkpoints.json" '"auto_reframed"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_id": "milestone-003"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_id": "milestone-004"'
expect_contains "$TASK_DIR/handoff.md" 'Stop reason: manual_pause'
expect_contains /tmp/campfire_reframe_resume.out 'auto_reframe: True'
expect_contains /tmp/campfire_reframe_resume.out 'reframe_queue_below: 1'
expect_contains /tmp/campfire_reframe_resume.out 'target_queue_depth: 3'
expect_contains /tmp/campfire_reframe_resume.out 'max_reframes_per_run: 1'
expect_contains /tmp/campfire_reframe_resume.out 'stop_reason: manual_pause'
expect_contains /tmp/campfire_reframe_resume.out 'events:'
expect_contains /tmp/campfire_reframe_resume.out 'auto_reframed'
expect_contains /tmp/campfire_reframe_resume.out 'milestone-004: Wrap the dynamically extended run with evaluation evidence'

echo "PASS: Rolling reframe verification completed."
