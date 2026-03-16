#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
COMPLETE_SLICE_SCRIPT="$SKILL_DIR/scripts/complete_slice.sh"
RECORD_SCRIPT="$SKILL_DIR/scripts/record_improvement_candidate.sh"
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

echo "== Syntax checks =="
zsh -n \
  "$INIT_SCRIPT" \
  "$START_SLICE_SCRIPT" \
  "$COMPLETE_SLICE_SCRIPT" \
  "$RECORD_SCRIPT" \
  "$DOCTOR_SCRIPT"
python3 -m py_compile "$SQL_HELPER"

echo "== Session lineage flow =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE"' EXIT
TASK_SLUG="verify-session-lineage"
BENCHMARK_RUN_ID="benchmark-resume-after-interrupt"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify session lineage" >/dev/null

"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --milestone-id "milestone-001" \
  --milestone-title "Initial branch" \
  --slice-id "initial-pass" \
  --slice-title "Run the initial pass" \
  --next-slice "Retry after the blocker." \
  "$TASK_SLUG" >/dev/null

RUN_ONE_ID="$(python3 - <<'PY' "$TEMP_WORKSPACE" "$TASK_SLUG"
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
task = sys.argv[2]
payload = json.loads((root / ".autonomous" / task / "checkpoints.json").read_text())
print(payload["last_run"]["run_id"])
PY
)"

"$COMPLETE_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --status blocked \
  --summary "Blocked on the first attempt." \
  --next-step "Retry with a narrower branch." \
  --next-slice "Retry the run with more targeted validation." \
  "$TASK_SLUG" >/dev/null

"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --milestone-id "milestone-001" \
  --milestone-title "Initial branch" \
  --slice-id "retry-pass" \
  --slice-title "Retry after the blocker" \
  --next-slice "Record the benchmark repro branch." \
  --parent-run-id "$RUN_ONE_ID" \
  --lineage-kind retry \
  --branch-label "retry-after-blocker" \
  "$TASK_SLUG" >/dev/null

RUN_TWO_ID="$(python3 - <<'PY' "$TEMP_WORKSPACE" "$TASK_SLUG"
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
task = sys.argv[2]
payload = json.loads((root / ".autonomous" / task / "checkpoints.json").read_text())
print(payload["last_run"]["run_id"])
PY
)"

"$COMPLETE_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --status validated \
  --summary "Validated the retry branch." \
  --next-step "Capture a benchmark repro branch." \
  --next-slice "Start the benchmark repro branch." \
  "$TASK_SLUG" >/dev/null

"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --milestone-id "milestone-002" \
  --milestone-title "Benchmark repro branch" \
  --slice-id "benchmark-repro" \
  --slice-title "Replay the benchmark repro" \
  --next-slice "Record retrospective evidence against this branch." \
  --run-id "$BENCHMARK_RUN_ID" \
  --parent-run-id "$RUN_TWO_ID" \
  --lineage-kind benchmark_repro \
  --branch-label "resume-after-interrupt" \
  "$TASK_SLUG" >/dev/null

"$RECORD_SCRIPT" --root "$TEMP_WORKSPACE" \
  --task-slug "$TASK_SLUG" \
  --candidate-id "lineage-candidate" \
  --category "control_plane_candidate" \
  --scope "repo_local" \
  --title "Keep run branches queryable" \
  --problem "Retry and benchmark repro branches should remain linked to the exact run they came from." \
  --source-run-id "$BENCHMARK_RUN_ID" \
  --next-action "Keep the lineage fields in task context and verifier coverage." \
  >/dev/null

expect_file "$TEMP_WORKSPACE/.campfire/registry.json"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/task_context.json"

python3 - "$TEMP_WORKSPACE" "$TASK_SLUG" "$RUN_ONE_ID" "$RUN_TWO_ID" "$BENCHMARK_RUN_ID" <<'PY'
import json
import sqlite3
import sys
from pathlib import Path

workspace = Path(sys.argv[1]).resolve()
task_slug = sys.argv[2]
run_one_id = sys.argv[3]
run_two_id = sys.argv[4]
benchmark_run_id = sys.argv[5]

task_context = json.loads((workspace / ".autonomous" / task_slug / "task_context.json").read_text())
last_run = task_context.get("last_run", {})
lineage = last_run.get("lineage", {})
if last_run.get("run_id") != benchmark_run_id:
    raise SystemExit("task_context latest run_id mismatch")
if lineage.get("parent_run_id") != run_two_id:
    raise SystemExit("task_context lineage parent mismatch")
if lineage.get("kind") != "benchmark_repro":
    raise SystemExit("task_context lineage kind mismatch")

recent = task_context.get("recent_improvement_candidates", [])
if not recent or recent[0]["source"]["run_id"] != benchmark_run_id:
    raise SystemExit("improvement candidate source run mismatch")

registry = json.loads((workspace / ".campfire" / "registry.json").read_text())
task_entry = next(item for item in registry["tasks"] if item["task_slug"] == task_slug)
registry_last_run = task_entry.get("last_run", {})
if registry_last_run.get("run_id") != benchmark_run_id:
    raise SystemExit("registry latest run_id mismatch")
if registry_last_run.get("lineage", {}).get("kind") != "benchmark_repro":
    raise SystemExit("registry lineage kind mismatch")

conn = sqlite3.connect(workspace / ".campfire" / "campfire.db")
conn.row_factory = sqlite3.Row
rows = conn.execute(
    """
    SELECT run_id, parent_run_id, lineage_kind, branch_label
    FROM sessions s
    JOIN tasks t ON t.id = s.task_id
    WHERE t.slug = ?
    ORDER BY started_at ASC
    """,
    (task_slug,),
).fetchall()
if len(rows) != 3:
    raise SystemExit(f"expected 3 sessions, found {len(rows)}")
if rows[0]["run_id"] != run_one_id or rows[0]["parent_run_id"] not in {"", None}:
    raise SystemExit("initial run lineage mismatch")
if rows[1]["run_id"] != run_two_id or rows[1]["parent_run_id"] != run_one_id or rows[1]["lineage_kind"] != "retry":
    raise SystemExit("retry run lineage mismatch")
if rows[2]["run_id"] != benchmark_run_id or rows[2]["parent_run_id"] != run_two_id or rows[2]["lineage_kind"] != "benchmark_repro":
    raise SystemExit("benchmark repro lineage mismatch")

print("Session lineage state verified.")
PY

"$DOCTOR_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/dev/null

echo "PASS: Session lineage verification completed."
