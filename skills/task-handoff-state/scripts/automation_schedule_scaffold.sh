#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_HELPER="${SQL_HELPER:-$SCRIPT_DIR/campfire_sql.py}"
PROPOSAL_HELPER_SCRIPT="${PROPOSAL_HELPER_SCRIPT:-$SCRIPT_DIR/automation_proposal_helper.sh}"
JSON_OUTPUT=false
VARIANTS=()
POSITIONAL=()

usage() {
  cat <<'EOF'
Usage:
  automation_schedule_scaffold.sh [--root /path/to/workspace] [--variant rolling_resume|verifier_sweep|backlog_refresh]... [--json] <task-slug>
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
  echo "python3 is required to build automation schedule scaffolds" >&2
  exit 1
fi

ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
TASK_ROOT="$(python3 "$SQL_HELPER" show-project --root "$ROOT_DIR" --field task_root)"
TASK_DIR="$ROOT_DIR/$TASK_ROOT/$TASK_SLUG"
CHECKPOINT_FILE="$TASK_DIR/checkpoints.json"

if [ ! -d "$TASK_DIR" ]; then
  echo "Task not found: $TASK_DIR" >&2
  exit 1
fi

if [ ! -f "$CHECKPOINT_FILE" ]; then
  echo "Missing checkpoints.json: $CHECKPOINT_FILE" >&2
  exit 1
fi

if [ ! -x "$PROPOSAL_HELPER_SCRIPT" ]; then
  echo "Missing automation proposal helper: $PROPOSAL_HELPER_SCRIPT" >&2
  exit 1
fi

VARIANT_LINES="$(printf '%s\n' "${VARIANTS[@]}")"
export ROOT_DIR TASK_SLUG CHECKPOINT_FILE PROPOSAL_HELPER_SCRIPT JSON_OUTPUT VARIANT_LINES

python3 <<'PY'
import json
import os
import subprocess
from pathlib import Path


def load_json(path: Path) -> dict:
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise SystemExit(f"Expected a JSON object in {path}")
    return data


requested_variants = [
    line.strip() for line in os.environ["VARIANT_LINES"].splitlines() if line.strip()
]
json_output = os.environ["JSON_OUTPUT"].strip().lower() == "true"
root_dir = Path(os.environ["ROOT_DIR"]).resolve()
task_slug = os.environ["TASK_SLUG"].strip()
checkpoints = load_json(Path(os.environ["CHECKPOINT_FILE"]))

execution = checkpoints.get("execution", {})
if not isinstance(execution, dict):
    execution = {}

helper_args = [
    os.environ["PROPOSAL_HELPER_SCRIPT"],
    "--root",
    str(root_dir),
    "--json",
]
for variant in requested_variants:
    helper_args.extend(["--variant", variant])
helper_args.append(task_slug)

payload = json.loads(
    subprocess.run(
        helper_args,
        check=True,
        capture_output=True,
        text=True,
    ).stdout
)

proposals = payload.get("proposals", [])
if not isinstance(proposals, list):
    raise SystemExit("Expected proposal helper to return a list of proposals")

guidance_by_variant = {
    "rolling_resume": {
        "cadence_label": "Nightly rolling resume",
        "cadence_summary": "Revisit active rolling work on a recurring cadence while queued milestones or open slices remain.",
        "schedule_examples": [
            "nightly while the rolling backlog is active",
            "every weekday morning during active delivery",
        ],
        "operator_questions": [
            "How often should this task be revisited while active?",
            "Should the cadence pause on weekends or continue daily?",
        ],
    },
    "verifier_sweep": {
        "cadence_label": "Nightly verifier sweep",
        "cadence_summary": "Rerun the strongest listed validation on a lightweight recurring cadence when implementation is mostly complete.",
        "schedule_examples": [
            "nightly verifier sweep",
            "pre-release verification window",
        ],
        "operator_questions": [
            "Should this run every night or only around release windows?",
            "Should failures reopen work immediately or wait for the next task boundary?",
        ],
    },
    "backlog_refresh": {
        "cadence_label": "Weekly backlog refresh",
        "cadence_summary": "Refresh stale queued milestones and assumptions on a slower planning cadence.",
        "schedule_examples": [
            "weekly backlog review",
            "after the queue drops below the reframe threshold",
        ],
        "operator_questions": [
            "Which weekly window fits planning refresh work?",
            "Should this only run when the queue gets short or on a fixed weekly cadence?",
        ],
    },
}

scaffolds = []
for proposal in proposals:
    variant = str(proposal.get("variant", "")).strip()
    if variant not in guidance_by_variant:
        raise SystemExit(f"Unknown proposal variant from helper: {variant}")
    guidance = guidance_by_variant[variant]
    scaffolds.append(
        {
            "variant": variant,
            "proposal_name": proposal.get("name", ""),
            "cadence_label": guidance["cadence_label"],
            "cadence_summary": guidance["cadence_summary"],
            "schedule_examples": guidance["schedule_examples"],
            "operator_questions": guidance["operator_questions"],
            "notes": [
                "Keep schedule outside the task prompt and proposal metadata.",
                "Reuse the stable workspace root from the existing proposal helper output.",
                "Choose cadence in the automation layer or operator flow, not in Campfire core state.",
            ],
            "guidance_source": "skills/task-handoff-state/references/automation-patterns.md",
            "scheduler_binding": "operator_owned",
            "platform_scope": "generic",
            "local_first": True,
            "mode": proposal.get("mode", execution.get("mode", "")),
            "run_style": proposal.get("run_style", execution.get("run_style", "")),
            "current_milestone_id": proposal.get("current_milestone_id", ""),
            "current_slice_id": proposal.get("current_slice_id", ""),
        }
    )

schedule_payload = {
    "task_slug": payload.get("task_slug", task_slug),
    "project_name": payload.get("project_name", ""),
    "root": payload.get("root", str(root_dir)),
    "scaffolds": scaffolds,
}

if json_output:
    print(json.dumps(schedule_payload, indent=2))
    raise SystemExit(0)

for index, scaffold in enumerate(scaffolds, start=1):
    if index > 1:
        print()
    print(f"{scaffold['variant']}:")
    print(f"  proposal_name: {scaffold['proposal_name']}")
    print(f"  cadence_label: {scaffold['cadence_label']}")
    print(f"  cadence_summary: {scaffold['cadence_summary']}")
    print("  schedule_examples:")
    for example in scaffold["schedule_examples"]:
        print(f"    - {example}")
    print("  operator_questions:")
    for question in scaffold["operator_questions"]:
        print(f"    - {question}")
    print("  notes:")
    for note in scaffold["notes"]:
        print(f"    - {note}")
    print(f"  guidance_source: {scaffold['guidance_source']}")
    print(f"  scheduler_binding: {scaffold['scheduler_binding']}")
    print(f"  platform_scope: {scaffold['platform_scope']}")
    print(f"  local_first: {str(scaffold['local_first']).lower()}")
    print(f"  mode: {scaffold['mode']}")
    print(f"  run_style: {scaffold['run_style']}")
PY
