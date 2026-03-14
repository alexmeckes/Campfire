#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_task_evaluation.sh"

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

echo "== Task evaluation simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_eval_init.out /tmp/campfire_eval_resume.out' EXIT
TASK_SLUG="verify-task-evaluation"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify task evaluation handling" >/tmp/campfire_eval_init.out

expect_file "$TASK_DIR/checkpoints.json"
expect_file "$TASK_DIR/handoff.md"
expect_file "$TASK_DIR/progress.md"
expect_file "$TASK_DIR/artifacts.json"

cat > "$TASK_DIR/artifacts/milestone-001-proof.txt" <<'EOF'
primary validation passed
EOF

cat > "$TASK_DIR/findings/milestone-001-evaluation.md" <<'EOF'
# milestone-001 evaluation

- Result: validated
- Evidence: `artifacts/milestone-001-proof.txt`
- Notes: all listed acceptance criteria were supported by concrete evidence.
EOF

cat >> "$TASK_DIR/progress.md" <<'EOF'

## 2026-03-14 milestone-001 evaluation

- Changed: simulated an independent evaluator pass over the current milestone.
- Validation: evaluator reviewed `artifacts/milestone-001-proof.txt` and recorded findings in `findings/milestone-001-evaluation.md`.
- Blockers: none.
- Next slice: define milestone-002 after the evaluated milestone is accepted.
EOF

cat > "$TASK_DIR/handoff.md" <<'EOF'
# Handoff

## Current Status

- Status: validated
- Current milestone: milestone-001 - Evaluated milestone completion
- Next slice: define milestone-002 after the evaluated milestone is accepted
- Stop reason: milestone_validated

## Resume Prompt

Use $task-evaluator and $task-handoff-state to review this task from `.autonomous/verify-task-evaluation/` whenever a milestone needs an explicit evaluation pass.
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
checkpoint["status"] = "validated"
checkpoint["phase"] = "verification"
checkpoint["current"] = {
    "milestone_id": "milestone-001",
    "milestone_title": "Evaluated milestone completion",
    "slice_id": "slice-002",
    "slice_title": "Confirm the milestone with an independent evaluation note",
    "acceptance_criteria": [
        "The milestone has concrete validation evidence",
        "The evaluator recorded an explicit pass or fail decision",
    ],
    "dependencies": [
        "artifacts.json",
        "findings/milestone-001-evaluation.md"
    ],
}
checkpoint["last_run"] = {
    "started_at": "2026-03-14T18:25:00Z",
    "ended_at": "2026-03-14T18:27:00Z",
    "stop_reason": "milestone_validated",
    "summary": "Independent evaluation confirmed the milestone had sufficient evidence.",
    "next_step": "Define milestone-002 after the validated evaluation pass."
}
checkpoint["validation"] = [
    {
        "type": "file_check",
        "result": "pass",
        "command": "test -f artifacts/milestone-001-proof.txt",
        "artifact": "artifacts/milestone-001-proof.txt",
        "summary": "Primary milestone proof exists."
    },
    {
        "type": "milestone_evaluation",
        "result": "pass",
        "command": "review findings/milestone-001-evaluation.md",
        "artifact": "findings/milestone-001-evaluation.md",
        "summary": "Independent evaluation confirmed the milestone."
    }
]
checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n")

artifacts = json.loads(artifacts_path.read_text())
artifacts["artifacts"] = [
    {
        "path": "artifacts/milestone-001-proof.txt",
        "type": "validation_log",
        "milestone_id": "milestone-001",
        "reason": "Primary proof for the simulated milestone."
    },
    {
        "path": "findings/milestone-001-evaluation.md",
        "type": "evaluation_note",
        "milestone_id": "milestone-001",
        "reason": "Independent evaluation decision for the simulated milestone."
    }
]
artifacts_path.write_text(json.dumps(artifacts, indent=2) + "\n")
PY

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_eval_resume.out

expect_contains "$TASK_DIR/checkpoints.json" '"type": "milestone_evaluation"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_title": "Evaluated milestone completion"'
expect_contains "$TASK_DIR/checkpoints.json" '"stop_reason": "milestone_validated"'
expect_contains "$TASK_DIR/handoff.md" 'Current milestone: milestone-001 - Evaluated milestone completion'
expect_contains "$TASK_DIR/artifacts.json" '"path": "findings/milestone-001-evaluation.md"'
expect_contains /tmp/campfire_eval_resume.out 'findings/milestone-001-evaluation.md'
expect_contains /tmp/campfire_eval_resume.out 'Evaluated milestone completion'
expect_contains /tmp/campfire_eval_resume.out 'milestone_validated'

echo "PASS: Task evaluation verification completed."
