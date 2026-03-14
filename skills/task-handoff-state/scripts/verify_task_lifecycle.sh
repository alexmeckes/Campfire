#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_task_lifecycle.sh"

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

echo "== Generic lifecycle simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_lifecycle_init.out /tmp/campfire_lifecycle_resume.out' EXIT
TASK_SLUG="verify-lifecycle"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify milestone lifecycle" >/tmp/campfire_lifecycle_init.out

expect_file "$TASK_DIR/plan.md"
expect_file "$TASK_DIR/runbook.md"
expect_file "$TASK_DIR/progress.md"
expect_file "$TASK_DIR/handoff.md"
expect_file "$TASK_DIR/checkpoints.json"
expect_file "$TASK_DIR/artifacts.json"

ARTIFACT_FILE="$TASK_DIR/artifacts/milestone-001.txt"
cat > "$ARTIFACT_FILE" <<'EOF'
simulated validation artifact
EOF

cat >> "$TASK_DIR/progress.md" <<'EOF'

## 2026-03-14 milestone-001

- Changed: simulated one validated milestone transition.
- Validation: created `artifacts/milestone-001.txt` and recorded structured checkpoint evidence.
- Blockers: none.
- Next slice: define milestone-002 acceptance criteria.
EOF

cat > "$TASK_DIR/handoff.md" <<'EOF'
# Handoff

## Current Status

- Status: validated
- Current milestone: milestone-001 - Simulated milestone validation
- Next slice: define milestone-002 acceptance criteria
- Stop reason: milestone_validated

## Resume Prompt

Use $long-horizon-worker and $task-handoff-state to continue this task from `.autonomous/verify-lifecycle/` and keep working until the current milestone is validated or a real blocker appears.
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
    "milestone_title": "Simulated milestone validation",
    "slice_id": "slice-001",
    "slice_title": "Record simulated validation evidence",
    "acceptance_criteria": [
        "Task files updated to validated state",
        "Validation artifact exists",
    ],
    "dependencies": ["runbook.md", "artifacts.json"],
}
checkpoint["blocker"] = {
    "status": "none",
    "type": "",
    "summary": "",
    "attempts": 0,
    "next_action": "",
}
checkpoint["last_run"] = {
    "started_at": "2026-03-14T16:40:00Z",
    "ended_at": "2026-03-14T16:41:00Z",
    "stop_reason": "milestone_validated",
    "summary": "Simulated one validated milestone update.",
    "next_step": "Define milestone-002 acceptance criteria.",
}
checkpoint["validation"] = [
    {
        "type": "file_check",
        "result": "pass",
        "command": "test -f artifacts/milestone-001.txt",
        "artifact": "artifacts/milestone-001.txt",
        "summary": "Created simulated validation artifact.",
    }
]
checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n")

artifacts = json.loads(artifacts_path.read_text())
artifacts["artifacts"] = [
    {
        "path": "artifacts/milestone-001.txt",
        "type": "validation_log",
        "milestone_id": "milestone-001",
        "reason": "Evidence for the simulated validated milestone transition.",
    }
]
artifacts_path.write_text(json.dumps(artifacts, indent=2) + "\n")
PY

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_lifecycle_resume.out

expect_contains "$TASK_DIR/checkpoints.json" '"status": "validated"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_title": "Simulated milestone validation"'
expect_contains "$TASK_DIR/checkpoints.json" '"stop_reason": "milestone_validated"'
expect_contains "$TASK_DIR/artifacts.json" '"path": "artifacts/milestone-001.txt"'
expect_contains "$TASK_DIR/handoff.md" 'Current milestone: milestone-001 - Simulated milestone validation'
expect_contains /tmp/campfire_lifecycle_resume.out 'Artifact manifest:'
expect_contains /tmp/campfire_lifecycle_resume.out 'Simulated milestone validation'
expect_contains /tmp/campfire_lifecycle_resume.out 'milestone_validated'

echo "PASS: Task lifecycle verification completed."
