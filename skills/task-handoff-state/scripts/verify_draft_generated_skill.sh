#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
RECORD_SCRIPT="$SKILL_DIR/scripts/record_improvement_candidate.sh"
DRAFT_SCRIPT="$SKILL_DIR/scripts/draft_generated_skill.sh"
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
zsh -n "$INIT_SCRIPT" "$RECORD_SCRIPT" "$DRAFT_SCRIPT" "$DOCTOR_SCRIPT"
python3 -m py_compile "$SQL_HELPER"

echo "== Generated skill drafting =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_draft_skill_fail.out /tmp/campfire_draft_skill_fail.err /tmp/campfire_rollback_candidate.json' EXIT
TASK_SLUG="verify-draft-generated-skill"
TASK_ROOT=".tasks"

cat >"$TEMP_WORKSPACE/campfire.toml" <<'EOF'
version = 1
project_name = "Draft Skill Verifier"
default_task_root = ".tasks"
EOF

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify generated skill drafting" >/dev/null

"$RECORD_SCRIPT" --root "$TEMP_WORKSPACE" \
  --task-slug "$TASK_SLUG" \
  --candidate-id "repo-skill-candidate" \
  --category "skill_candidate" \
  --scope "repo_local" \
  --title "Draft repo-local generated skill" \
  --problem "Repo-local draft skills should be scaffolded mechanically." \
  --proposed-skill-name "repo-skill-helper" \
  --proposed-skill-purpose "Scaffold repo-local generated skills from structured candidates." \
  --next-action "Review the repo-local draft." \
  >/dev/null

"$DRAFT_SCRIPT" --root "$TEMP_WORKSPACE" "repo-skill-candidate" >/dev/null

"$RECORD_SCRIPT" --root "$TEMP_WORKSPACE" \
  --task-slug "$TASK_SLUG" \
  --candidate-id "task-skill-candidate" \
  --category "skill_candidate" \
  --scope "task_local" \
  --title "Draft task-local generated skill" \
  --problem "Task-local draft skills should be scaffolded mechanically." \
  --proposed-skill-name "task-skill-helper" \
  --proposed-skill-purpose "Scaffold task-local generated skills from structured candidates." \
  --next-action "Review the task-local draft." \
  >/dev/null

"$DRAFT_SCRIPT" --root "$TEMP_WORKSPACE" --scope task_local "task-skill-candidate" >/dev/null

expect_file "$TEMP_WORKSPACE/.campfire/generated-skills/repo-skill-helper/SKILL.md"
expect_file "$TEMP_WORKSPACE/.campfire/generated-skills/repo-skill-helper/skill_candidate.json"
expect_file "$TEMP_WORKSPACE/$TASK_ROOT/$TASK_SLUG/generated-skills/task-skill-helper/SKILL.md"
expect_file "$TEMP_WORKSPACE/$TASK_ROOT/$TASK_SLUG/generated-skills/task-skill-helper/skill_candidate.json"
expect_file "$TEMP_WORKSPACE/.campfire/skill_inventory.json"

python3 - "$TEMP_WORKSPACE" "$TASK_SLUG" "$TASK_ROOT" <<'PY'
import json
import sys
from pathlib import Path

workspace = Path(sys.argv[1]).resolve()
task_slug = sys.argv[2]
task_root = sys.argv[3]

inventory = json.loads((workspace / ".campfire" / "skill_inventory.json").read_text())
skills = inventory.get("skills", [])
repo_entry = next(item for item in skills if item["skill_name"] == "repo-skill-helper")
task_entry = next(item for item in skills if item["skill_name"] == "task-skill-helper")
if repo_entry["scope"] != "repo_local_generated":
    raise SystemExit("repo-local draft scope mismatch")
if task_entry["scope"] != "task_local_generated":
    raise SystemExit("task-local draft scope mismatch")
if task_entry["task_slug"] != task_slug:
    raise SystemExit("task-local draft task slug mismatch")

task_context = json.loads((workspace / task_root / task_slug / "task_context.json").read_text())
repo_local = task_context.get("skill_surfaces", {}).get("repo_local_generated", [])
task_local = task_context.get("skill_surfaces", {}).get("task_local_generated", [])
if not any(item.get("skill_name") == "repo-skill-helper" for item in repo_local):
    raise SystemExit("task_context missing repo-local draft")
if not any(item.get("skill_name") == "task-skill-helper" for item in task_local):
    raise SystemExit("task_context missing task-local draft")

project_context = json.loads((workspace / ".campfire" / "project_context.json").read_text())
repo_skills = project_context.get("discoverable_skills", {}).get("repo_local_generated", [])
if not any(item.get("skill_name") == "repo-skill-helper" for item in repo_skills):
    raise SystemExit("project_context missing repo-local draft")

repo_candidate = json.loads((workspace / ".campfire" / "generated-skills" / "repo-skill-helper" / "skill_candidate.json").read_text())
task_candidate = json.loads((workspace / task_root / task_slug / "generated-skills" / "task-skill-helper" / "skill_candidate.json").read_text())
if repo_candidate.get("promotion_state") != "drafted":
    raise SystemExit("repo-local candidate not marked drafted")
if task_candidate.get("promotion_state") != "drafted":
    raise SystemExit("task-local candidate not marked drafted")

print("Draft generated skill state verified.")
PY

"$RECORD_SCRIPT" --root "$TEMP_WORKSPACE" \
  --task-slug "$TASK_SLUG" \
  --candidate-id "rollback-skill-candidate" \
  --category "skill_candidate" \
  --scope "repo_local" \
  --title "Rollback repo-local generated skill" \
  --problem "Draft generation should roll back if refresh fails." \
  --proposed-skill-name "rollback-skill-helper" \
  --proposed-skill-purpose "Exercise rollback when draft generation refresh fails." \
  --next-action "Verify rollback restored the original candidate state." \
  >/dev/null

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
  "$DRAFT_SCRIPT" --root "$TEMP_WORKSPACE" "rollback-skill-candidate" \
  >/tmp/campfire_draft_skill_fail.out 2>/tmp/campfire_draft_skill_fail.err; then
  fail "draft_generated_skill.sh should fail when refresh_registry.sh fails"
fi

expect_contains /tmp/campfire_draft_skill_fail.err 'Failed to draft generated skill:'
if [ -e "$TEMP_WORKSPACE/.campfire/generated-skills/rollback-skill-helper" ]; then
  fail "rollback-generated skill scaffold persisted after refresh failure"
fi

python3 "$SQL_HELPER" show-improvement-candidate --root "$TEMP_WORKSPACE" rollback-skill-candidate >/tmp/campfire_rollback_candidate.json
python3 - "$TEMP_WORKSPACE" <<'PY'
import json
import sys
from pathlib import Path

workspace = Path(sys.argv[1]).resolve()
candidate = json.loads(Path("/tmp/campfire_rollback_candidate.json").read_text())
if candidate.get("promotion_state") != "proposed":
    raise SystemExit("rollback candidate was not restored to proposed")

inventory = json.loads((workspace / ".campfire" / "skill_inventory.json").read_text())
if any(item.get("skill_name") == "rollback-skill-helper" for item in inventory.get("skills", [])):
    raise SystemExit("rollback skill unexpectedly persisted in skill inventory")
PY

"$DOCTOR_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/dev/null

echo "PASS: Draft generated skill verification completed."
