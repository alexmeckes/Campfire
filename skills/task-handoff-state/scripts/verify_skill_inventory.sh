#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
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
zsh -n "$INIT_SCRIPT" "$REFRESH_REGISTRY_SCRIPT" "$DOCTOR_SCRIPT"
python3 -m py_compile "$SQL_HELPER"

echo "== Skill inventory discovery =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE"' EXIT
TASK_SLUG="verify-skill-inventory"

cat >"$TEMP_WORKSPACE/campfire.toml" <<'EOF'
version = 1
project_name = "Skill Inventory Fixture"
default_task_root = ".autonomous"
EOF

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify skill inventory" >/dev/null

mkdir -p "$TEMP_WORKSPACE/skills/core-skill"
cat >"$TEMP_WORKSPACE/skills/core-skill/SKILL.md" <<'EOF'
# Core Skill
EOF

mkdir -p "$TEMP_WORKSPACE/.campfire/generated-skills/repo-draft-skill"
cat >"$TEMP_WORKSPACE/.campfire/generated-skills/repo-draft-skill/SKILL.md" <<'EOF'
# Repo Draft Skill
EOF
cat >"$TEMP_WORKSPACE/.campfire/generated-skills/repo-draft-skill/skill_candidate.json" <<'EOF'
{
  "candidate_id": "repo-draft-skill",
  "promotion_state": "drafted"
}
EOF

mkdir -p "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/generated-skills/task-draft-skill"
cat >"$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/generated-skills/task-draft-skill/SKILL.md" <<'EOF'
# Task Draft Skill
EOF
cat >"$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/generated-skills/task-draft-skill/skill_candidate.json" <<'EOF'
{
  "candidate_id": "task-draft-skill",
  "promotion_state": "trialing"
}
EOF

"$REFRESH_REGISTRY_SCRIPT" --root "$TEMP_WORKSPACE" >/dev/null

expect_file "$TEMP_WORKSPACE/.campfire/skill_inventory.json"
expect_file "$TEMP_WORKSPACE/.campfire/project_context.json"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/task_context.json"

python3 - "$TEMP_WORKSPACE" "$TASK_SLUG" <<'PY'
import json
import sys
from pathlib import Path

workspace = Path(sys.argv[1]).resolve()
task_slug = sys.argv[2]

inventory = json.loads((workspace / ".campfire" / "skill_inventory.json").read_text())
skills = inventory.get("skills", [])
if len(skills) != 3:
    raise SystemExit(f"expected 3 discovered skills, found {len(skills)}")

def find(scope, name):
    for entry in skills:
        if entry.get("scope") == scope and entry.get("skill_name") == name:
            return entry
    raise SystemExit(f"missing {scope}:{name}")

core = find("core", "core-skill")
if core.get("package_name") != "core-skill":
    raise SystemExit("unexpected core package name")

repo = find("repo_local_generated", "repo-draft-skill")
if repo.get("package_name") != "repo-local--repo-draft-skill":
    raise SystemExit("unexpected repo-local package name")
if repo.get("candidate_id") != "repo-draft-skill":
    raise SystemExit("repo-local candidate metadata missing")

task = find("task_local_generated", "task-draft-skill")
if task.get("task_slug") != task_slug:
    raise SystemExit("task-local skill missing task slug")
if task.get("package_name") != f"{task_slug}--task-draft-skill":
    raise SystemExit("unexpected task-local package name")

project_context = json.loads((workspace / ".campfire" / "project_context.json").read_text())
if project_context.get("skill_inventory_path") != str(workspace / ".campfire" / "skill_inventory.json"):
    raise SystemExit("project_context skill inventory path mismatch")
repo_skills = project_context.get("discoverable_skills", {}).get("repo_local_generated", [])
if len(repo_skills) != 1 or repo_skills[0].get("skill_name") != "repo-draft-skill":
    raise SystemExit("project_context repo-local skill discovery mismatch")

task_context = json.loads((workspace / ".autonomous" / task_slug / "task_context.json").read_text())
if task_context.get("skill_inventory_path") != str(workspace / ".campfire" / "skill_inventory.json"):
    raise SystemExit("task_context skill inventory path mismatch")
task_skills = task_context.get("skill_surfaces", {}).get("task_local_generated", [])
if len(task_skills) != 1 or task_skills[0].get("skill_name") != "task-draft-skill":
    raise SystemExit("task_context task-local skill discovery mismatch")

print("Skill inventory state verified.")
PY

"$DOCTOR_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/dev/null

echo "PASS: Skill inventory verification completed."
