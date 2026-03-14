#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
PLANNING_SLICE_MINUTES=10
RUNTIME_BUDGET_MINUTES=120
MAX_MILESTONES_PER_RUN=3
CONTINUE_UNTIL="blocked,waiting_on_decision,budget_limit,manual_pause"
NOTE_TEXT=""

usage() {
  cat <<'EOF'
Usage:
  enable_rolling_mode.sh [--root /path/to/workspace] [--planning-slice-minutes N] [--runtime-budget-minutes N] [--max-milestones-per-run N] [--continue-until csv] [--note "text"] [--queue "milestone-id:Milestone title"]... <task-slug>
EOF
}

QUEUE_VALUES=()
POSITIONAL=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --planning-slice-minutes)
      PLANNING_SLICE_MINUTES="$2"
      shift 2
      ;;
    --runtime-budget-minutes)
      RUNTIME_BUDGET_MINUTES="$2"
      shift 2
      ;;
    --max-milestones-per-run)
      MAX_MILESTONES_PER_RUN="$2"
      shift 2
      ;;
    --continue-until)
      CONTINUE_UNTIL="$2"
      shift 2
      ;;
    --note)
      NOTE_TEXT="$2"
      shift 2
      ;;
    --queue)
      QUEUE_VALUES+=("$2")
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
HANDOFF_FILE="$TASK_DIR/handoff.md"

if [ ! -d "$TASK_DIR" ]; then
  echo "Task not found: $TASK_DIR" >&2
  exit 1
fi

if [ ! -f "$CHECKPOINT_FILE" ]; then
  echo "Missing checkpoints.json: $CHECKPOINT_FILE" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to enable rolling mode" >&2
  exit 1
fi

QUEUE_JSON="$(printf '%s\n' "${QUEUE_VALUES[@]}")"

export CHECKPOINT_FILE HANDOFF_FILE TASK_SLUG PLANNING_SLICE_MINUTES RUNTIME_BUDGET_MINUTES MAX_MILESTONES_PER_RUN CONTINUE_UNTIL NOTE_TEXT QUEUE_JSON

python3 <<'PY'
import json
import os
from pathlib import Path

checkpoint_path = Path(os.environ["CHECKPOINT_FILE"])
handoff_path = Path(os.environ["HANDOFF_FILE"])
task_slug = os.environ["TASK_SLUG"]
planning_slice_minutes = int(os.environ["PLANNING_SLICE_MINUTES"])
runtime_budget_minutes = int(os.environ["RUNTIME_BUDGET_MINUTES"])
max_milestones_per_run = int(os.environ["MAX_MILESTONES_PER_RUN"])
continue_until = [item.strip() for item in os.environ["CONTINUE_UNTIL"].split(",") if item.strip()]
note_text = os.environ["NOTE_TEXT"].strip()
queue_lines = [line.strip() for line in os.environ["QUEUE_JSON"].splitlines() if line.strip()]

data = json.loads(checkpoint_path.read_text())
execution = data.get("execution", {})
if not isinstance(execution, dict):
    execution = {}

queued_milestones = execution.get("queued_milestones", [])
if queue_lines:
    queued_milestones = []
    for line in queue_lines:
      if ":" not in line:
        raise SystemExit(f"Invalid --queue value: {line!r}. Expected milestone-id:Milestone title")
      milestone_id, milestone_title = line.split(":", 1)
      queued_milestones.append(
          {
              "milestone_id": milestone_id.strip(),
              "milestone_title": milestone_title.strip(),
          }
      )

execution.update(
    {
        "mode": "rolling",
        "auto_advance": True,
        "planning_slice_minutes": planning_slice_minutes,
        "runtime_budget_minutes": runtime_budget_minutes,
        "max_milestones_per_run": max_milestones_per_run,
        "continue_until": continue_until,
        "queued_milestones": queued_milestones,
        "notes": note_text or execution.get("notes", ""),
    }
)
data["execution"] = execution
checkpoint_path.write_text(json.dumps(data, indent=2) + "\n")

rolling_prompt = (
    f"Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state "
    f"to continue this task from `.autonomous/{task_slug}/`. Keep planning bounded, auto-advance through the "
    f"queued milestones, and stop only on a real blocker, decision boundary, budget limit, or manual pause."
)

if handoff_path.exists():
    lines = handoff_path.read_text().splitlines()
else:
    lines = ["# Handoff", "", "## Resume Prompt", ""]

if "## Resume Prompt" in lines:
    idx = lines.index("## Resume Prompt")
    updated = lines[: idx + 1] + ["", rolling_prompt]
else:
    updated = lines + ["", "## Resume Prompt", "", rolling_prompt]

handoff_path.write_text("\n".join(updated).rstrip() + "\n")
PY

echo "Enabled rolling mode for:"
echo "  $TASK_DIR"
echo
echo "Recommended Codex App prompt:"
echo "  Use \$task-framer, \$course-corrector, \$long-horizon-worker, \$task-evaluator, and \$task-handoff-state to continue .autonomous/$TASK_SLUG/. Keep planning bounded, auto-advance through queued milestones, and stop only on a real blocker, decision boundary, budget limit, or manual pause."
