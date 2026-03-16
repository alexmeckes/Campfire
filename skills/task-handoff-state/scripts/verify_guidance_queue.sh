#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
QUEUE_GUIDANCE_SCRIPT="$SKILL_DIR/scripts/queue_guidance.sh"
DOCTOR_SCRIPT="$SKILL_DIR/scripts/doctor_task.sh"
SQL_HELPER="$SKILL_DIR/scripts/campfire_sql.py"
REFRESH_SCRIPT="$SKILL_DIR/scripts/refresh_registry.sh"

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
zsh -n "$INIT_SCRIPT" "$START_SLICE_SCRIPT" "$QUEUE_GUIDANCE_SCRIPT" "$DOCTOR_SCRIPT"
python3 -m py_compile "$SQL_HELPER"

echo "== Guidance queue flow =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_guidance_fail.out /tmp/campfire_guidance_fail.err' EXIT
TASK_SLUG="verify-guidance-queue"
DB_PATH="$TEMP_WORKSPACE/.campfire/campfire.db"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify guidance queue" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --milestone-id "milestone-001" \
  --milestone-title "Guidance persistence" \
  --slice-id "queue-guidance" \
  --slice-title "Persist interrupt and boundary guidance" \
  --next-slice "Validate guidance projections." \
  "$TASK_SLUG" >/dev/null

"$QUEUE_GUIDANCE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --mode next_boundary \
  --summary "Revisit session lineage after the current milestone." \
  --details "This should stay queued until the next safe boundary." \
  "$TASK_SLUG" >/dev/null

"$QUEUE_GUIDANCE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --mode interrupt_now \
  --summary "Stop and inspect the failing verifier immediately." \
  --details "This should surface as active steering." \
  "$TASK_SLUG" >/dev/null

expect_file "$DB_PATH"
expect_file "$TEMP_WORKSPACE/.campfire/registry.json"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/task_context.json"

python3 - "$TEMP_WORKSPACE" "$DB_PATH" "$TASK_SLUG" <<'PY'
import json
import sqlite3
import sys
from pathlib import Path

workspace = Path(sys.argv[1])
db_path = sys.argv[2]
task_slug = sys.argv[3]

checkpoint = json.loads((workspace / ".autonomous" / task_slug / "checkpoints.json").read_text())
guidance = checkpoint.get("guidance", {})
active = guidance.get("active", {})
follow_ups = guidance.get("follow_ups", [])
if active.get("mode") != "interrupt_now":
    raise SystemExit("checkpoint active guidance mode mismatch")
if active.get("summary") != "Stop and inspect the failing verifier immediately.":
    raise SystemExit("checkpoint active guidance summary mismatch")
if len(follow_ups) != 1 or follow_ups[0].get("mode") != "next_boundary":
    raise SystemExit("checkpoint follow-up guidance missing")

task_context = json.loads((workspace / ".autonomous" / task_slug / "task_context.json").read_text())
context_guidance = task_context.get("guidance", {})
if context_guidance.get("active", {}).get("summary") != active.get("summary"):
    raise SystemExit("task_context active guidance summary mismatch")
if len(context_guidance.get("follow_ups", [])) != 1:
    raise SystemExit("task_context follow-up guidance count mismatch")

registry = json.loads((workspace / ".campfire" / "registry.json").read_text())
task_entry = next(item for item in registry["tasks"] if item["task_slug"] == task_slug)
registry_guidance = task_entry.get("guidance", {})
if registry_guidance.get("active_count") != 1:
    raise SystemExit("registry active guidance count mismatch")
if registry_guidance.get("follow_up_count") != 1:
    raise SystemExit("registry follow-up guidance count mismatch")
if registry_guidance.get("active_mode") != "interrupt_now":
    raise SystemExit("registry active guidance mode mismatch")

conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
rows = conn.execute(
    """
    SELECT active, position, mode, summary
    FROM guidance_entries g
    JOIN tasks t ON t.id = g.task_id
    WHERE t.slug = ?
    ORDER BY active DESC, position ASC
    """,
    (task_slug,),
).fetchall()
if len(rows) != 2:
    raise SystemExit(f"expected 2 guidance rows, found {len(rows)}")
if rows[0]["active"] != 1 or rows[0]["mode"] != "interrupt_now":
    raise SystemExit("active guidance row missing from db")
if rows[1]["active"] != 0 or rows[1]["mode"] != "next_boundary":
    raise SystemExit("follow-up guidance row missing from db")

print("Guidance queue state verified.")
PY

cp "$TASK_DIR/checkpoints.json" "$TEMP_WORKSPACE/checkpoints.before.json"
cp "$TASK_DIR/task_context.json" "$TEMP_WORKSPACE/task_context.before.json"
cp "$TEMP_WORKSPACE/.campfire/registry.json" "$TEMP_WORKSPACE/registry.before.json"

cat >"$TEMP_WORKSPACE/fail_once_refresh.sh" <<EOF
#!/bin/zsh
set -euo pipefail
MARKER="$TEMP_WORKSPACE/fail_once_refresh.marker"
REAL_REFRESH="$REFRESH_SCRIPT"
if [ ! -f "\$MARKER" ]; then
  : >"\$MARKER"
  echo "forced refresh failure" >&2
  exit 1
fi
exec "\$REAL_REFRESH" "\$@"
EOF
chmod +x "$TEMP_WORKSPACE/fail_once_refresh.sh"

if REFRESH_REGISTRY_SCRIPT="$TEMP_WORKSPACE/fail_once_refresh.sh" \
  "$QUEUE_GUIDANCE_SCRIPT" --root "$TEMP_WORKSPACE" \
    --mode next_boundary \
    --summary "This guidance should roll back." \
    "$TASK_SLUG" >/tmp/campfire_guidance_fail.out 2>/tmp/campfire_guidance_fail.err; then
  fail "queue_guidance.sh should fail when refresh_registry.sh fails"
fi

cmp -s "$TASK_DIR/checkpoints.json" "$TEMP_WORKSPACE/checkpoints.before.json" || fail "checkpoints.json changed after refresh failure"
expect_contains /tmp/campfire_guidance_fail.err 'restored checkpoints.json'

python3 - "$TEMP_WORKSPACE" "$TASK_SLUG" <<'PY'
import json
import sys
from pathlib import Path

workspace = Path(sys.argv[1]).resolve()
task_slug = sys.argv[2]

before_task = json.loads((workspace / "task_context.before.json").read_text())
after_task = json.loads((workspace / ".autonomous" / task_slug / "task_context.json").read_text())
if before_task.get("guidance") != after_task.get("guidance"):
    raise SystemExit("task_context guidance changed after refresh failure")

before_registry = json.loads((workspace / "registry.before.json").read_text())
after_registry = json.loads((workspace / ".campfire" / "registry.json").read_text())
before_entry = next(item for item in before_registry["tasks"] if item["task_slug"] == task_slug)
after_entry = next(item for item in after_registry["tasks"] if item["task_slug"] == task_slug)
if before_entry.get("guidance") != after_entry.get("guidance"):
    raise SystemExit("registry guidance changed after refresh failure")
PY

python3 - "$DB_PATH" "$TASK_SLUG" <<'PY'
import sqlite3
import sys

conn = sqlite3.connect(sys.argv[1])
conn.row_factory = sqlite3.Row
rows = conn.execute(
    """
    SELECT summary
    FROM guidance_entries g
    JOIN tasks t ON t.id = g.task_id
    WHERE t.slug = ?
    ORDER BY active DESC, position ASC
    """,
    (sys.argv[2],),
).fetchall()
summaries = [row["summary"] for row in rows]
if "This guidance should roll back." in summaries:
    raise SystemExit("rollback guidance unexpectedly persisted in the db")
if len(rows) != 2:
    raise SystemExit(f"expected 2 guidance rows after rollback, found {len(rows)}")
PY

"$DOCTOR_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/dev/null

echo "PASS: Guidance queue verification completed."
