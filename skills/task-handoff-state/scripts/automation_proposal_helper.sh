#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPT_TEMPLATE_SCRIPT="$SCRIPT_DIR/prompt_template_helper.sh"
JSON_OUTPUT=false
VARIANTS=()
POSITIONAL=()

usage() {
  cat <<'EOF'
Usage:
  automation_proposal_helper.sh [--root /path/to/workspace] [--variant rolling_resume|verifier_sweep|backlog_refresh]... [--json] <task-slug>
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --variant)
      VARIANTS+=("$2")
      shift 2
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
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

TASK_SLUG="${POSITIONAL[1]}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to build automation proposals" >&2
  exit 1
fi

ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
TASK_DIR="$ROOT_DIR/.autonomous/$TASK_SLUG"
TASK_CONTEXT_FILE="$TASK_DIR/task_context.json"
PROJECT_CONTEXT_FILE="$ROOT_DIR/.campfire/project_context.json"
CHECKPOINT_FILE="$TASK_DIR/checkpoints.json"

if [ ! -d "$TASK_DIR" ]; then
  echo "Task not found: $TASK_DIR" >&2
  exit 1
fi

if [ ! -f "$CHECKPOINT_FILE" ]; then
  echo "Missing checkpoints.json: $CHECKPOINT_FILE" >&2
  exit 1
fi

if [ ! -x "$PROMPT_TEMPLATE_SCRIPT" ]; then
  echo "Missing prompt template helper: $PROMPT_TEMPLATE_SCRIPT" >&2
  exit 1
fi

VARIANT_LINES="$(printf '%s\n' "${VARIANTS[@]}")"
export ROOT_DIR TASK_SLUG TASK_CONTEXT_FILE PROJECT_CONTEXT_FILE CHECKPOINT_FILE PROMPT_TEMPLATE_SCRIPT JSON_OUTPUT VARIANT_LINES

python3 <<'PY'
import json
import os
import subprocess
from pathlib import Path


def load_optional_json(path: Path) -> dict:
    if not path.is_file():
        return {}
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise SystemExit(f"Expected a JSON object in {path}")
    return data


def render_prompt(template: str) -> str:
    completed = subprocess.run(
        [
            os.environ["PROMPT_TEMPLATE_SCRIPT"],
            "--root",
            os.environ["ROOT_DIR"],
            "--task-slug",
            os.environ["TASK_SLUG"],
            template,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


root_dir = Path(os.environ["ROOT_DIR"]).resolve()
task_slug = os.environ["TASK_SLUG"].strip()
json_output = os.environ["JSON_OUTPUT"].strip().lower() == "true"
requested_variants = [
    line.strip() for line in os.environ["VARIANT_LINES"].splitlines() if line.strip()
]

task_context = load_optional_json(Path(os.environ["TASK_CONTEXT_FILE"]))
project_context = load_optional_json(Path(os.environ["PROJECT_CONTEXT_FILE"]))
checkpoints = load_optional_json(Path(os.environ["CHECKPOINT_FILE"]))

execution = checkpoints.get("execution", {})
if not isinstance(execution, dict):
    execution = {}
current = task_context.get("current", {})
if not isinstance(current, dict):
    current = checkpoints.get("current", {})
if not isinstance(current, dict):
    current = {}

supported_variants = {"rolling_resume", "verifier_sweep", "backlog_refresh"}
selected_variants = requested_variants or [
    "rolling_resume",
    "verifier_sweep",
    "backlog_refresh",
]
unknown = [item for item in selected_variants if item not in supported_variants]
if unknown:
    raise SystemExit(f"Unknown variant(s): {', '.join(unknown)}")

project_name = str(task_context.get("project_name") or project_context.get("project_name") or "").strip()
mode = str(execution.get("mode", "single_milestone")).strip()
run_style = str(execution.get("run_style", "bounded")).strip()
current_milestone_id = str(current.get("milestone_id", "")).strip()
current_milestone_title = str(current.get("milestone_title", "")).strip()
current_slice_id = str(current.get("slice_id", "")).strip()
current_slice_title = str(current.get("slice_title", "")).strip()

name_by_variant = {
    "rolling_resume": f"Continue {task_slug}",
    "verifier_sweep": f"Sweep {task_slug} verifier",
    "backlog_refresh": f"Refresh {task_slug} backlog",
}

proposals = []
for variant in selected_variants:
    proposals.append(
        {
            "variant": variant,
            "name": name_by_variant[variant],
            "prompt": render_prompt(variant),
            "cwds": [str(root_dir)],
            "status": "ACTIVE",
            "task_slug": task_slug,
            "project_name": project_name,
            "mode": mode,
            "run_style": run_style,
            "current_milestone_id": current_milestone_id,
            "current_milestone_title": current_milestone_title,
            "current_slice_id": current_slice_id,
            "current_slice_title": current_slice_title,
        }
    )

payload = {
    "task_slug": task_slug,
    "project_name": project_name,
    "root": str(root_dir),
    "proposals": proposals,
}

if json_output:
    print(json.dumps(payload, indent=2))
    raise SystemExit(0)

for index, proposal in enumerate(proposals, start=1):
    if index > 1:
        print()
    print(f"{proposal['variant']}:")
    print(f"  name: {proposal['name']}")
    print(f"  prompt: {proposal['prompt']}")
    print("  cwds:")
    for cwd in proposal["cwds"]:
        print(f"    - {cwd}")
    print(f"  status: {proposal['status']}")
    if proposal["current_milestone_id"]:
        title = proposal["current_milestone_title"] or proposal["current_milestone_id"]
        print(f"  current_milestone: {proposal['current_milestone_id']} - {title}")
    if proposal["current_slice_id"]:
        title = proposal["current_slice_title"] or proposal["current_slice_id"]
        print(f"  current_slice: {proposal['current_slice_id']} - {title}")
    print(f"  mode: {proposal['mode']}")
    print(f"  run_style: {proposal['run_style']}")
PY
