#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_HELPER="${SQL_HELPER:-$SCRIPT_DIR/campfire_sql.py}"
PROMPT_TEMPLATE_SCRIPT="$SCRIPT_DIR/prompt_template_helper.sh"
RUN_STYLE="bounded"
PLANNING_SLICE_MINUTES=10
RUNTIME_BUDGET_MINUTES=120
MIN_RUNTIME_MINUTES=60
MIN_MILESTONES_PER_RUN=5
MAX_MILESTONES_PER_RUN=8
AUTO_REFRAME=true
REFRAME_QUEUE_BELOW=1
TARGET_QUEUE_DEPTH=5
MAX_REFRAMES_PER_RUN=3
CONTINUE_UNTIL="blocked,waiting_on_decision,budget_limit"
NOTE_TEXT=""

usage() {
  cat <<'EOF'
Usage:
  enable_rolling_mode.sh [--root /path/to/workspace] [--run-style bounded|until_stopped] [--until-stopped] [--planning-slice-minutes N] [--runtime-budget-minutes N] [--min-runtime-minutes N] [--min-milestones-per-run N] [--max-milestones-per-run N] [--auto-reframe true|false] [--reframe-queue-below N] [--target-queue-depth N] [--max-reframes-per-run N] [--continue-until csv] [--note "text"] [--queue "milestone-id:Milestone title"]... <task-slug>
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
    --run-style)
      RUN_STYLE="$2"
      shift 2
      ;;
    --until-stopped)
      RUN_STYLE="until_stopped"
      shift
      ;;
    --planning-slice-minutes)
      PLANNING_SLICE_MINUTES="$2"
      shift 2
      ;;
    --runtime-budget-minutes)
      RUNTIME_BUDGET_MINUTES="$2"
      shift 2
      ;;
    --min-runtime-minutes)
      MIN_RUNTIME_MINUTES="$2"
      shift 2
      ;;
    --min-milestones-per-run)
      MIN_MILESTONES_PER_RUN="$2"
      shift 2
      ;;
    --max-milestones-per-run)
      MAX_MILESTONES_PER_RUN="$2"
      shift 2
      ;;
    --auto-reframe)
      AUTO_REFRAME="$2"
      shift 2
      ;;
    --reframe-queue-below)
      REFRAME_QUEUE_BELOW="$2"
      shift 2
      ;;
    --target-queue-depth)
      TARGET_QUEUE_DEPTH="$2"
      shift 2
      ;;
    --max-reframes-per-run)
      MAX_REFRAMES_PER_RUN="$2"
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
TASK_ROOT="$(python3 "$SQL_HELPER" show-project --root "$ROOT_DIR" --field task_root)"
TASK_DIR="$ROOT_DIR/$TASK_ROOT/$TASK_SLUG"
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

export CHECKPOINT_FILE HANDOFF_FILE TASK_SLUG RUN_STYLE PLANNING_SLICE_MINUTES RUNTIME_BUDGET_MINUTES MIN_RUNTIME_MINUTES MIN_MILESTONES_PER_RUN MAX_MILESTONES_PER_RUN AUTO_REFRAME REFRAME_QUEUE_BELOW TARGET_QUEUE_DEPTH MAX_REFRAMES_PER_RUN CONTINUE_UNTIL NOTE_TEXT QUEUE_JSON

python3 <<'PY'
import json
import os
from pathlib import Path

checkpoint_path = Path(os.environ["CHECKPOINT_FILE"])
handoff_path = Path(os.environ["HANDOFF_FILE"])
task_slug = os.environ["TASK_SLUG"]
run_style = os.environ["RUN_STYLE"].strip()
planning_slice_minutes = int(os.environ["PLANNING_SLICE_MINUTES"])
runtime_budget_minutes = int(os.environ["RUNTIME_BUDGET_MINUTES"])
min_runtime_minutes = int(os.environ["MIN_RUNTIME_MINUTES"])
min_milestones_per_run = int(os.environ["MIN_MILESTONES_PER_RUN"])
max_milestones_per_run = int(os.environ["MAX_MILESTONES_PER_RUN"])
auto_reframe = os.environ["AUTO_REFRAME"].strip().lower() in {"1", "true", "yes", "on"}
reframe_queue_below = int(os.environ["REFRAME_QUEUE_BELOW"])
target_queue_depth = int(os.environ["TARGET_QUEUE_DEPTH"])
max_reframes_per_run = int(os.environ["MAX_REFRAMES_PER_RUN"])
continue_until = [item.strip() for item in os.environ["CONTINUE_UNTIL"].split(",") if item.strip()]
note_text = os.environ["NOTE_TEXT"].strip()
queue_lines = [line.strip() for line in os.environ["QUEUE_JSON"].splitlines() if line.strip()]

if run_style not in {"bounded", "until_stopped"}:
    raise SystemExit("--run-style must be one of: bounded, until_stopped")

if run_style == "until_stopped":
    runtime_budget_minutes = 0
    min_runtime_minutes = 0
    min_milestones_per_run = 0
    max_milestones_per_run = 0
    max_reframes_per_run = 0
    continue_until = ["blocked", "waiting_on_decision"]

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

if min_milestones_per_run > max_milestones_per_run:
    raise SystemExit("--min-milestones-per-run cannot exceed --max-milestones-per-run")

execution.update(
    {
        "mode": "rolling",
        "run_style": run_style,
        "auto_advance": True,
        "auto_reframe": auto_reframe,
        "planning_slice_minutes": planning_slice_minutes,
        "runtime_budget_minutes": runtime_budget_minutes,
        "min_runtime_minutes": min_runtime_minutes,
        "min_milestones_per_run": min_milestones_per_run,
        "max_milestones_per_run": max_milestones_per_run,
        "reframe_queue_below": reframe_queue_below,
        "target_queue_depth": target_queue_depth,
        "max_reframes_per_run": max_reframes_per_run,
        "continue_until": continue_until,
        "queued_milestones": queued_milestones,
        "notes": note_text or execution.get("notes", ""),
    }
)
data["execution"] = execution
checkpoint_path.write_text(json.dumps(data, indent=2) + "\n")
PY

ROLLING_PROMPT="$("$PROMPT_TEMPLATE_SCRIPT" --root "$ROOT_DIR" --task-slug "$TASK_SLUG" resume)"
export HANDOFF_FILE ROLLING_PROMPT

python3 <<'PY'
import os
from pathlib import Path

handoff_path = Path(os.environ["HANDOFF_FILE"])
rolling_prompt = os.environ["ROLLING_PROMPT"]

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
echo "  $ROLLING_PROMPT"
echo
echo "Suggested monitor sidecar:"
echo "  ./scripts/monitor_task_loop.sh $TASK_SLUG"
echo "  Keep it observer-only and let it write only .campfire/monitoring/ artifacts."
