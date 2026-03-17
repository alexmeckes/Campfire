#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_HELPER="${SQL_HELPER:-$SCRIPT_DIR/campfire_sql.py}"
REFRESH_REGISTRY_SCRIPT="${REFRESH_REGISTRY_SCRIPT:-$SCRIPT_DIR/refresh_registry.sh}"
SCOPE=""
TASK_SLUG=""
SKILL_NAME=""
PURPOSE_OVERRIDE=""
FORCE=false

usage() {
  cat <<'EOF'
Usage:
  draft_generated_skill.sh [--root /path/to/workspace] [--scope task_local|repo_local] [--task-slug slug] [--skill-name name] [--purpose text] [--force] <candidate-id>
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --scope)
      SCOPE="$2"
      shift 2
      ;;
    --task-slug)
      TASK_SLUG="$2"
      shift 2
      ;;
    --skill-name)
      SKILL_NAME="$2"
      shift 2
      ;;
    --purpose)
      PURPOSE_OVERRIDE="$2"
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to draft a generated skill" >&2
  exit 1
fi

CANDIDATE_ID="$1"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"

export ROOT_DIR SQL_HELPER REFRESH_REGISTRY_SCRIPT SCOPE TASK_SLUG SKILL_NAME PURPOSE_OVERRIDE FORCE CANDIDATE_ID

python3 <<'PY'
import json
import os
import re
import subprocess
from pathlib import Path


def slugify(value: str) -> str:
    lowered = value.strip().lower()
    lowered = re.sub(r"[^a-z0-9]+", "-", lowered)
    lowered = re.sub(r"-{2,}", "-", lowered).strip("-")
    return lowered or "generated-skill"


def run_json(*args: str) -> dict:
    completed = subprocess.run(args, check=True, capture_output=True, text=True)
    payload = json.loads(completed.stdout)
    if not isinstance(payload, dict):
        raise SystemExit("Expected JSON object from helper")
    return payload


def format_command_error(exc: Exception) -> str:
    if isinstance(exc, subprocess.CalledProcessError):
        detail = (exc.stderr or exc.stdout or "").strip()
        if detail:
            return detail
    return str(exc)


def restore_text_file(path: Path, existed: bool, original_text: str) -> None:
    if existed:
        path.write_text(original_text)
    elif path.exists():
        path.unlink()


def refresh_registry() -> None:
    subprocess.run(
        [refresh_registry_script, "--root", str(root_dir)],
        check=True,
        capture_output=True,
        text=True,
    )


root_dir = Path(os.environ["ROOT_DIR"]).resolve()
sql_helper = os.environ["SQL_HELPER"]
refresh_registry_script = os.environ["REFRESH_REGISTRY_SCRIPT"]
candidate_id = os.environ["CANDIDATE_ID"].strip()
requested_scope = os.environ["SCOPE"].strip()
requested_task_slug = os.environ["TASK_SLUG"].strip()
requested_skill_name = os.environ["SKILL_NAME"].strip()
purpose_override = os.environ["PURPOSE_OVERRIDE"].strip()
force = os.environ["FORCE"].strip().lower() == "true"

project = run_json("python3", sql_helper, "show-project", "--root", str(root_dir))
task_root = str(project.get("task_root", "")).strip() or ".autonomous"
candidate = run_json("python3", sql_helper, "show-improvement-candidate", "--root", str(root_dir), candidate_id)

candidate_scope = str(candidate.get("scope", "")).strip()
source = candidate.get("source", {})
if not isinstance(source, dict):
    source = {}
proposed_skill = candidate.get("proposed_skill", {})
if not isinstance(proposed_skill, dict):
    proposed_skill = {}

scope = requested_scope or ("repo_local" if candidate_scope == "repo_local" else "task_local")
if scope not in {"repo_local", "task_local"}:
    raise SystemExit(f"Unsupported draft scope: {scope}")

task_slug = requested_task_slug or str(source.get("task_slug", "")).strip()
if scope == "task_local" and not task_slug:
    raise SystemExit("task-local drafting requires --task-slug or a source task slug")

skill_name = requested_skill_name or str(proposed_skill.get("name", "")).strip() or slugify(str(candidate.get("title", "")).strip())
purpose = purpose_override or str(proposed_skill.get("purpose", "")).strip() or str(candidate.get("title", "")).strip()
if not purpose:
    purpose = "Draft generated skill"
previous_promotion_state = str(candidate.get("promotion_state", "")).strip()
previous_promoted_task_slug = str(candidate.get("promoted_task_slug", "")).strip()

if scope == "repo_local":
    target_dir = root_dir / ".campfire" / "generated-skills" / skill_name
else:
    target_dir = root_dir / task_root / task_slug / "generated-skills" / skill_name

target_dir_existed = target_dir.exists()
target_dir.mkdir(parents=True, exist_ok=True)
skill_path = target_dir / "SKILL.md"
candidate_path = target_dir / "skill_candidate.json"
skill_path_existed = skill_path.exists()
candidate_path_existed = candidate_path.exists()
skill_path_original = skill_path.read_text() if skill_path_existed else ""
candidate_path_original = candidate_path.read_text() if candidate_path_existed else ""

if not force and (skill_path.exists() or candidate_path.exists()):
    raise SystemExit(f"Draft skill already exists: {target_dir}")

promoted_applied = False
try:
    promoted = run_json(
        "python3",
        sql_helper,
        "promote-improvement-candidate",
        "--root",
        str(root_dir),
        "--promotion-state",
        "drafted",
        "--promoted-task-slug",
        "",
        candidate_id,
    )
    promoted_applied = True

    trigger_pattern = promoted.get("trigger_pattern", [])
    if not isinstance(trigger_pattern, list):
        trigger_pattern = []
    evidence = promoted.get("evidence", [])
    if not isinstance(evidence, list):
        evidence = []

    lines = [
        "---",
        f"name: {skill_name}",
        f"description: Draft generated skill for {purpose}.",
        "---",
        "",
        f"# {promoted.get('title', skill_name)}",
        "",
        "Draft generated skill scaffold. Review before wider reuse or promotion.",
        "",
        "## Source",
        "",
        f"- Candidate ID: `{candidate_id}`",
        f"- Scope: `{scope}`",
    ]
    if task_slug:
        lines.append(f"- Source task: `{task_slug}`")
    run_id = str(source.get("run_id", "")).strip()
    if run_id:
        lines.append(f"- Source run: `{run_id}`")
    lines.extend(
        [
            "",
            "## Purpose",
            "",
            purpose,
            "",
            "## Problem",
            "",
            str(promoted.get("problem", "")).strip() or "Document the recurring instructional gap here.",
            "",
            "## When To Use",
            "",
        ]
    )
    if trigger_pattern:
        lines.extend([f"- {item}" for item in trigger_pattern if str(item).strip()])
    else:
        lines.append("- Use when the candidate's recurring trigger pattern appears again.")
    lines.extend(
        [
            "",
            "## Draft Workflow",
            "",
            "1. Read the linked candidate metadata and current task context.",
            "2. Apply the narrow procedure this draft skill is meant to teach.",
            "3. Validate against the linked evidence before considering promotion.",
            "",
            "## Evidence",
            "",
        ]
    )
    if evidence:
        lines.extend([f"- {item}" for item in evidence if str(item).strip()])
    else:
        lines.append("- Add evidence paths before promoting this draft.")
    lines.extend(
        [
            "",
            "## Next Action",
            "",
            str(promoted.get("next_action", "")).strip() or "Review and iterate on the draft.",
            "",
        ]
    )

    skill_path.write_text("\n".join(lines))
    candidate_path.write_text(json.dumps(promoted, indent=2) + "\n")
    refresh_registry()
except Exception as exc:
    rollback_errors = []
    try:
        restore_text_file(skill_path, skill_path_existed, skill_path_original)
    except Exception as rollback_exc:
        rollback_errors.append(
            f"failed to restore {skill_path}: {format_command_error(rollback_exc)}"
        )
    try:
        restore_text_file(candidate_path, candidate_path_existed, candidate_path_original)
    except Exception as rollback_exc:
        rollback_errors.append(
            f"failed to restore {candidate_path}: {format_command_error(rollback_exc)}"
        )
    try:
        if not target_dir_existed and target_dir.exists() and not any(target_dir.iterdir()):
            target_dir.rmdir()
    except Exception as rollback_exc:
        rollback_errors.append(
            f"failed to remove {target_dir}: {format_command_error(rollback_exc)}"
        )
    if promoted_applied:
        try:
            run_json(
                "python3",
                sql_helper,
                "promote-improvement-candidate",
                "--root",
                str(root_dir),
                "--promotion-state",
                previous_promotion_state,
                "--promoted-task-slug",
                previous_promoted_task_slug,
                candidate_id,
            )
        except Exception as rollback_exc:
            rollback_errors.append(
                "failed to restore improvement candidate promotion state: "
                f"{format_command_error(rollback_exc)}"
            )
    try:
        refresh_registry()
    except Exception as rollback_exc:
        rollback_errors.append(
            "failed to refresh registry after rollback: "
            f"{format_command_error(rollback_exc)}"
        )

    message = f"Failed to draft generated skill: {format_command_error(exc)}"
    if rollback_errors:
        message += " Rollback incomplete: " + "; ".join(rollback_errors)
    raise SystemExit(message)

print(f"Drafted generated skill: {skill_name}")
print(f"  scope: {scope}")
print(f"  path: {target_dir}")
print(f"  candidate_id: {candidate_id}")
PY
