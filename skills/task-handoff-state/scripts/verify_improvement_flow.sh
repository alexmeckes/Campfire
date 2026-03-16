#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
COMPLETE_SLICE_SCRIPT="$SKILL_DIR/scripts/complete_slice.sh"
RECORD_SCRIPT="$SKILL_DIR/scripts/record_improvement_candidate.sh"
PROMOTE_SCRIPT="$SKILL_DIR/scripts/promote_improvement.sh"
DOCTOR_SCRIPT="$SKILL_DIR/scripts/doctor_task.sh"
SQL_HELPER="$SKILL_DIR/scripts/campfire_sql.py"

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
zsh -n \
  "$INIT_SCRIPT" \
  "$START_SLICE_SCRIPT" \
  "$COMPLETE_SLICE_SCRIPT" \
  "$RECORD_SCRIPT" \
  "$PROMOTE_SCRIPT" \
  "$DOCTOR_SCRIPT"
python3 -m py_compile "$SQL_HELPER"

echo "== Improvement candidate flow =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE"' EXIT
TASK_SLUG="verify-improvement-flow"
CANDIDATE_ID="slice-start-guard"
PROMOTED_TASK="improve-slice-start-guard"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify improvement flow" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --milestone-id "milestone-001" \
  --milestone-title "Find workflow drift" \
  --slice-id "retrospect" \
  --slice-title "Retrospect the run" \
  --next-slice "Record the improvement candidate." \
  "$TASK_SLUG" >/dev/null
"$COMPLETE_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --status validated \
  --summary "Validated the retrospective slice." \
  --next-step "Record the improvement candidate." \
  --next-slice "Promote the candidate if it looks reusable." \
  "$TASK_SLUG" >/dev/null

"$RECORD_SCRIPT" --root "$TEMP_WORKSPACE" \
  --task-slug "$TASK_SLUG" \
  --candidate-id "$CANDIDATE_ID" \
  --category "skill_candidate" \
  --scope "repo_local" \
  --title "Strengthen slice-start discipline" \
  --problem "Workers sometimes begin editing before the active slice transition is written." \
  --why-not-script "The helper exists, but the worker also needs a reusable pre-edit procedure." \
  --evidence ".autonomous/$TASK_SLUG/checkpoints.json" \
  --evidence ".autonomous/$TASK_SLUG/progress.md" \
  --trigger-pattern "project file edits before slice_started" \
  --proposed-skill-name "slice-start-guard" \
  --proposed-skill-purpose "Force a short pre-edit checklist for active slice state and proof target." \
  --confidence "medium" \
  --next-action "Draft a repo-local micro-skill and benchmark whether it reduces stale-state runs." \
  >/dev/null

expect_file "$TEMP_WORKSPACE/.campfire/improvement_backlog.json"
expect_file "$TEMP_WORKSPACE/.campfire/project_context.json"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/task_context.json"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/findings/$CANDIDATE_ID.json"

python3 - "$TEMP_WORKSPACE/.campfire/campfire.db" "$TASK_SLUG" "$CANDIDATE_ID" <<'PY'
import json
import sqlite3
import sys
from pathlib import Path

db_path = sys.argv[1]
task_slug = sys.argv[2]
candidate_id = sys.argv[3]
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row

candidate = conn.execute(
    """
    SELECT title, category, scope, promotion_state, source_task_slug
    FROM improvement_candidates
    WHERE candidate_id = ?
    """,
    (candidate_id,),
).fetchone()
if candidate is None:
    raise SystemExit("candidate row missing")
if candidate["promotion_state"] != "proposed":
    raise SystemExit(f"unexpected promotion state: {candidate['promotion_state']}")
if candidate["source_task_slug"] != task_slug:
    raise SystemExit("source task slug not synced")

project_context = json.loads(Path(Path(db_path).parent / "project_context.json").read_text())
if project_context["improvement_counts"]["total"] != 1:
    raise SystemExit("project_context improvement count mismatch")

task_context = json.loads(Path(Path(db_path).parent.parent / ".autonomous" / task_slug / "task_context.json").read_text())
recent = task_context.get("recent_improvement_candidates", [])
if not recent or recent[0]["candidate_id"] != candidate_id:
    raise SystemExit("task_context missing recent improvement candidate")
PY

"$PROMOTE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --task-slug "$PROMOTED_TASK" \
  "$CANDIDATE_ID" >/dev/null

expect_file "$TEMP_WORKSPACE/.autonomous/$PROMOTED_TASK/plan.md"
expect_contains "$TEMP_WORKSPACE/.autonomous/$PROMOTED_TASK/plan.md" "Candidate ID: $CANDIDATE_ID"
expect_contains "$TEMP_WORKSPACE/.autonomous/$PROMOTED_TASK/handoff.md" "Candidate ID: $CANDIDATE_ID"

python3 - "$TEMP_WORKSPACE/.campfire/campfire.db" "$CANDIDATE_ID" "$PROMOTED_TASK" <<'PY'
import sqlite3
import sys

db_path = sys.argv[1]
candidate_id = sys.argv[2]
promoted_task = sys.argv[3]
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row

candidate = conn.execute(
    """
    SELECT promotion_state, promoted_task_slug
    FROM improvement_candidates
    WHERE candidate_id = ?
    """,
    (candidate_id,),
).fetchone()
if candidate is None:
    raise SystemExit("candidate row missing after promotion")
if candidate["promotion_state"] != "promoted_repo_local":
    raise SystemExit(f"unexpected promoted state: {candidate['promotion_state']}")
if candidate["promoted_task_slug"] != promoted_task:
    raise SystemExit("promoted task slug not synced")
PY

"$DOCTOR_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/dev/null
"$DOCTOR_SCRIPT" --root "$TEMP_WORKSPACE" "$PROMOTED_TASK" >/dev/null

echo "PASS: Improvement flow verification completed."
