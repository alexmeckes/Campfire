#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
COMPLETE_SLICE_SCRIPT="$SKILL_DIR/scripts/complete_slice.sh"
REFRESH_REGISTRY_SCRIPT="$SKILL_DIR/scripts/refresh_registry.sh"
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
zsh -n "$INIT_SCRIPT" "$START_SLICE_SCRIPT" "$COMPLETE_SLICE_SCRIPT" "$REFRESH_REGISTRY_SCRIPT" "$DOCTOR_SCRIPT"
python3 -m py_compile "$SQL_HELPER"

echo "== SQL control-plane lifecycle =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE"' EXIT
TASK_SLUG="verify-sql-control-plane"
DB_PATH="$TEMP_WORKSPACE/.campfire/campfire.db"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify sql control plane" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --milestone-id "milestone-001" \
  --milestone-title "Database-backed lifecycle" \
  --slice-id "sync-pass" \
  --slice-title "Sync the SQL control plane" \
  --next-slice "Validate SQL persistence." \
  "$TASK_SLUG" >/dev/null
"$COMPLETE_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --status validated \
  --summary "Validated SQL-backed lifecycle sync." \
  --next-step "Stop." \
  --next-slice "None." \
  "$TASK_SLUG" >/dev/null
"$REFRESH_REGISTRY_SCRIPT" --root "$TEMP_WORKSPACE" >/dev/null

expect_file "$DB_PATH"
expect_file "$TEMP_WORKSPACE/.campfire/registry.json"
expect_file "$TEMP_WORKSPACE/.campfire/project_context.json"
expect_file "$TEMP_WORKSPACE/.campfire/improvement_backlog.json"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/task_context.json"

python3 - "$DB_PATH" "$TASK_SLUG" <<'PY'
import sqlite3
import sys

db_path = sys.argv[1]
task_slug = sys.argv[2]
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row

task = conn.execute(
    "SELECT status, run_mode, run_style, current_milestone_key, current_slice_key FROM tasks WHERE slug = ?",
    (task_slug,),
).fetchone()
if task is None:
    raise SystemExit("task row missing")
if task["status"] != "validated":
    raise SystemExit(f"unexpected task status: {task['status']}")
if task["current_milestone_key"] != "milestone-001":
    raise SystemExit("current milestone not synced")
if task["current_slice_key"] != "sync-pass":
    raise SystemExit("current slice not synced")

heartbeat = conn.execute(
    "SELECT state FROM heartbeats JOIN tasks ON tasks.id = heartbeats.task_id WHERE tasks.slug = ?",
    (task_slug,),
).fetchone()
if heartbeat is None or heartbeat["state"] != "idle":
    raise SystemExit("heartbeat not synced to idle")

events = {
    row["event_type"]
    for row in conn.execute(
        "SELECT event_type FROM events JOIN tasks ON tasks.id = events.task_id WHERE tasks.slug = ?",
        (task_slug,),
    )
}
if "slice_started" not in events or "slice_completed" not in events:
    raise SystemExit(f"unexpected events: {sorted(events)}")

session = conn.execute(
    "SELECT stop_reason FROM sessions JOIN tasks ON tasks.id = sessions.task_id WHERE tasks.slug = ? ORDER BY started_at DESC LIMIT 1",
    (task_slug,),
).fetchone()
if session is None or session["stop_reason"] != "milestone_validated":
    raise SystemExit("latest session stop reason not synced")

print("SQL control-plane state verified.")
PY

"$DOCTOR_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/dev/null

echo "PASS: SQL control-plane verification completed."
