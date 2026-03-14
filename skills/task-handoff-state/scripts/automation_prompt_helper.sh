#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"

usage() {
  cat <<'EOF'
Usage:
  automation_prompt_helper.sh [--root /path/to/workspace] [--variant rolling_resume|verifier_sweep|backlog_refresh]... <task-slug>
EOF
}

VARIANTS=()
POSITIONAL=()
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
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
TASK_DIR="$ROOT_DIR/.autonomous/$TASK_SLUG"
CHECKPOINT_FILE="$TASK_DIR/checkpoints.json"

if [ ! -d "$TASK_DIR" ]; then
  echo "Task not found: $TASK_DIR" >&2
  exit 1
fi

if [ ! -f "$CHECKPOINT_FILE" ]; then
  echo "Missing checkpoints.json: $CHECKPOINT_FILE" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to print automation prompt variants" >&2
  exit 1
fi

VARIANTS_JSON="$(printf '%s\n' "${VARIANTS[@]}")"
export CHECKPOINT_FILE TASK_SLUG VARIANTS_JSON

python3 <<'PY'
import json
import os
from pathlib import Path

checkpoint_path = Path(os.environ["CHECKPOINT_FILE"])
task_slug = os.environ["TASK_SLUG"]
selected = [line.strip() for line in os.environ["VARIANTS_JSON"].splitlines() if line.strip()]

data = json.loads(checkpoint_path.read_text())
execution = data.get("execution", {})
if not isinstance(execution, dict):
    execution = {}

task_ref = f".autonomous/{task_slug}/"
mode = execution.get("mode", "single_milestone")
run_style = execution.get("run_style", "bounded")

allowed = {
    "rolling_resume",
    "verifier_sweep",
    "backlog_refresh",
}
if not selected:
    selected = ["rolling_resume", "verifier_sweep", "backlog_refresh"]

unknown = [item for item in selected if item not in allowed]
if unknown:
    raise SystemExit(f"Unknown variant(s): {', '.join(unknown)}")

if mode == "rolling":
    if run_style == "until_stopped":
        rolling_resume = (
            f"Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and "
            f"$task-handoff-state to continue {task_ref}. Keep planning bounded, auto-advance through "
            f"queued milestones, replenish the queue when policy allows, and keep going until a real blocker, "
            f"decision boundary, safe-work exhaustion, or an external manual pause appears. Do not impose an "
            f"internal runtime budget or milestone cap."
        )
    else:
        rolling_resume = (
            f"Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and "
            f"$task-handoff-state to continue {task_ref}. Keep planning bounded, auto-advance through queued "
            f"milestones, replenish the queue when policy allows and budget remains, do not self-pause before "
            f"the configured minimum runtime and milestone floor unless a blocker or decision boundary appears, "
            f"and stop only on blockers, real decision boundaries, or the configured run budget."
        )
else:
    rolling_resume = (
        f"Use $long-horizon-worker and $task-handoff-state to continue {task_ref} from the current handoff and "
        f"validate the next slice before stopping."
    )

prompts = {
    "rolling_resume": rolling_resume,
    "verifier_sweep": (
        f"Use $task-evaluator and $task-handoff-state to inspect {task_ref}, rerun the strongest validation "
        f"listed in runbook.md, refresh findings or artifacts only if evidence changed, and stop after updating "
        f"task state with the current evaluation result."
    ),
    "backlog_refresh": (
        f"Use $task-framer, $course-corrector, and $task-handoff-state to review {task_ref}, tighten the next "
        f"2 to 3 milestones, refresh execution policy if needed, preserve prior progress, and leave a new "
        f"handoff without broad implementation unless the new next slice is obvious and dependency-safe."
    ),
}

for index, variant in enumerate(selected):
    if index:
        print()
    print(f"{variant}:")
    print(f"  {prompts[variant]}")
PY
