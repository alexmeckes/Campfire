#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_course_correction.sh"

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

echo "== Course correction simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_course_init.out /tmp/campfire_course_resume.out' EXIT
TASK_SLUG="verify-course-correction"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify course correction handling" >/tmp/campfire_course_init.out

expect_file "$TASK_DIR/plan.md"
expect_file "$TASK_DIR/runbook.md"
expect_file "$TASK_DIR/progress.md"
expect_file "$TASK_DIR/handoff.md"
expect_file "$TASK_DIR/checkpoints.json"
expect_file "$TASK_DIR/artifacts.json"

cat > "$TASK_DIR/findings/course-correction-note.md" <<'EOF'
# Course Correction Note

- Discovery: direct integration requires unavailable credentials.
- Decision: switch from the naive direct path to a fixture-backed adapter path.
- Result: milestone ordering, runbook, and next slice all changed.
EOF

cat > "$TASK_DIR/plan.md" <<'EOF'
# verify-course-correction

## Objective

verify course correction handling

## Source Docs

- AGENTS.md
- runbook.md
- findings/course-correction-note.md

## Milestones

- [x] Record the initial naive direct-integration plan
- [x] Detect the new constraint that invalidates the naive path
- [ ] Build the adapter-first path
- [ ] Validate the corrected path and update handoff

## Notes

- Created: 2026-03-14
- Course correction: direct integration was replaced with an adapter-first path after discovering missing credentials
EOF

cat > "$TASK_DIR/runbook.md" <<'EOF'
# Runbook

## Workspace

- Root: temporary verification workspace
- Task: verify-course-correction

## Boot / Setup

- Simulate the product environment with a fixture-backed adapter path
- Do not depend on external credentials for the corrected path

## Validation

- Confirm the plan points at the adapter-first path
- Confirm the handoff and checkpoint state use the corrected milestone
- Store the re-plan note in `findings/course-correction-note.md`

## Observability

- Logs: .autonomous/verify-course-correction/logs/
- Artifacts: .autonomous/verify-course-correction/artifacts/
- Findings: .autonomous/verify-course-correction/findings/

## Notes

- The corrected path should stay dependency-safe even when the original integration is unavailable
EOF

cat >> "$TASK_DIR/progress.md" <<'EOF'

## 2026-03-14 course-correction

- Changed: replaced the naive direct-integration milestone with an adapter-first path after discovering missing credentials.
- Validation: updated `plan.md`, `runbook.md`, `handoff.md`, `checkpoints.json`, and `artifacts.json` to reflect the corrected path.
- Blockers: the original path is blocked by unavailable credentials, but the corrected path is ready to continue.
- Next slice: implement the fixture-backed adapter path.
EOF

cat > "$TASK_DIR/handoff.md" <<'EOF'
# Handoff

## Current Status

- Status: ready
- Current milestone: milestone-003 - Build the adapter-first path
- Next slice: implement the fixture-backed adapter path
- Stop reason: course_corrected

## Resume Prompt

Use $long-horizon-worker and $task-handoff-state to continue this task from `.autonomous/verify-course-correction/` and validate the corrected milestone before stopping again.
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
checkpoint["phase"] = "replanning"
checkpoint["current"] = {
    "milestone_id": "milestone-003",
    "milestone_title": "Build the adapter-first path",
    "slice_id": "slice-004",
    "slice_title": "Implement the fixture-backed adapter path",
    "acceptance_criteria": [
        "The new milestone no longer depends on external credentials",
        "The runbook documents the corrected validation path",
        "The next run resumes from the corrected milestone instead of the stale one"
    ],
    "dependencies": [
        "plan.md",
        "runbook.md",
        "findings/course-correction-note.md"
    ],
}
checkpoint["blocker"] = {
    "status": "none",
    "type": "",
    "summary": "",
    "attempts": 0,
    "next_action": "",
}
checkpoint["last_run"] = {
    "started_at": "2026-03-14T17:30:00Z",
    "ended_at": "2026-03-14T17:35:00Z",
    "stop_reason": "course_corrected",
    "summary": "Replaced the naive direct-integration path with a dependency-safe adapter-first plan.",
    "next_step": "Implement the fixture-backed adapter path."
}
checkpoint["validation"] = [
    {
        "type": "plan_review",
        "result": "pass",
        "command": "grep -q 'adapter-first path' plan.md handoff.md runbook.md",
        "artifact": "findings/course-correction-note.md",
        "summary": "The corrected milestone, runbook, and handoff now point at the adapter-first path."
    }
]
checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n")

artifacts = json.loads(artifacts_path.read_text())
artifacts["artifacts"] = [
    {
        "path": "findings/course-correction-note.md",
        "type": "planning_note",
        "milestone_id": "milestone-003",
        "reason": "Explains why the task changed course and what the new path is."
    }
]
artifacts_path.write_text(json.dumps(artifacts, indent=2) + "\n")
PY

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_course_resume.out

expect_contains "$TASK_DIR/plan.md" 'Build the adapter-first path'
expect_contains "$TASK_DIR/runbook.md" 'fixture-backed adapter path'
expect_contains "$TASK_DIR/checkpoints.json" '"phase": "replanning"'
expect_contains "$TASK_DIR/checkpoints.json" '"stop_reason": "course_corrected"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_title": "Build the adapter-first path"'
expect_contains "$TASK_DIR/handoff.md" 'Stop reason: course_corrected'
expect_contains "$TASK_DIR/artifacts.json" '"path": "findings/course-correction-note.md"'
expect_contains /tmp/campfire_course_resume.out 'course_corrected'
expect_contains /tmp/campfire_course_resume.out 'Build the adapter-first path'
expect_contains /tmp/campfire_course_resume.out 'fixture-backed adapter path'

echo "PASS: Course correction verification completed."
