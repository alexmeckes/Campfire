#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../templates/prompt_templates.json"
SQL_HELPER="${SQL_HELPER:-$SCRIPT_DIR/campfire_sql.py}"
TASK_SLUG=""
CANDIDATE_ID=""

usage() {
  cat <<'EOF'
Usage:
  prompt_template_helper.sh [--root /path/to/workspace] [--task-slug slug] [--candidate-id id] <template-name>

Template names:
  task_bootstrap
  resume
  rolling_resume
  verifier_sweep
  backlog_refresh
  retrospective
  benchmark
  improvement_promotion
EOF
}

POSITIONAL=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --task-slug)
      TASK_SLUG="$2"
      shift 2
      ;;
    --candidate-id)
      CANDIDATE_ID="$2"
      shift 2
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
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [ "${#POSITIONAL[@]}" -ne 1 ]; then
  usage >&2
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Missing prompt template file: $TEMPLATE_FILE" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to render prompt templates" >&2
  exit 1
fi

ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
TASK_ROOT="$(python3 "$SQL_HELPER" show-project --root "$ROOT_DIR" --field task_root)"
TEMPLATE_NAME="${POSITIONAL[1]}"

export ROOT_DIR TEMPLATE_FILE TASK_SLUG CANDIDATE_ID TEMPLATE_NAME TASK_ROOT

python3 <<'PY'
import json
import os
from pathlib import Path

root_dir = Path(os.environ["ROOT_DIR"])
template_file = Path(os.environ["TEMPLATE_FILE"])
task_slug = os.environ["TASK_SLUG"].strip()
candidate_id = os.environ["CANDIDATE_ID"].strip()
template_name = os.environ["TEMPLATE_NAME"].strip()
task_root = os.environ["TASK_ROOT"].strip() or ".autonomous"

templates = json.loads(template_file.read_text())
if not isinstance(templates, dict):
    raise SystemExit(f"Expected a JSON object in {template_file}")

aliases = {
    "rolling_resume": "resume",
}
requested_template = aliases.get(template_name, template_name)


def require_task() -> Path:
    if not task_slug:
        raise SystemExit(f"--task-slug is required for template '{template_name}'")
    task_dir = root_dir / task_root / task_slug
    if not task_dir.is_dir():
        raise SystemExit(f"Task not found: {task_dir}")
    return task_dir


context = {
    "task_ref": f"{task_root}/{task_slug}/" if task_slug else "",
    "benchmark_root": "benchmarks/campfire-bench/",
    "candidate_ref": f"`{candidate_id}`" if candidate_id else "the promoted improvement candidate",
}

if requested_template == "resume":
    task_dir = require_task()
    checkpoint_path = task_dir / "checkpoints.json"
    if not checkpoint_path.is_file():
        raise SystemExit(f"Missing checkpoints.json: {checkpoint_path}")
    data = json.loads(checkpoint_path.read_text())
    execution = data.get("execution", {})
    if not isinstance(execution, dict):
        execution = {}
    mode = execution.get("mode", "single_milestone")
    run_style = execution.get("run_style", "bounded")
    if mode == "rolling":
        if run_style == "until_stopped":
            requested_template = "resume.rolling.until_stopped"
        else:
            requested_template = "resume.rolling.bounded"
    else:
        requested_template = "resume.single"
elif requested_template in {"task_bootstrap", "verifier_sweep", "backlog_refresh", "retrospective", "improvement_promotion"}:
    require_task()
elif requested_template != "benchmark":
    available = ", ".join(
        [
            "task_bootstrap",
            "resume",
            "rolling_resume",
            "verifier_sweep",
            "backlog_refresh",
            "retrospective",
            "benchmark",
            "improvement_promotion",
        ]
    )
    raise SystemExit(f"Unknown template '{template_name}'. Available templates: {available}")

template = templates.get(requested_template)
if not isinstance(template, str) or not template.strip():
    raise SystemExit(f"Missing prompt template body for '{requested_template}'")

print(template.format_map(context))
PY
