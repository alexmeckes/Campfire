#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_HELPER="${SQL_HELPER:-$SCRIPT_DIR/campfire_sql.py}"
AUTOMATION_HELPER_SCRIPT="$SCRIPT_DIR/automation_prompt_helper.sh"
AUTOMATION_PROPOSAL_HELPER_SCRIPT="$SCRIPT_DIR/automation_proposal_helper.sh"
AUTOMATION_SCHEDULE_SCAFFOLD_SCRIPT="$SCRIPT_DIR/automation_schedule_scaffold.sh"
PROMPT_TEMPLATE_SCRIPT="$SCRIPT_DIR/prompt_template_helper.sh"
START_SLICE_SCRIPT="$SCRIPT_DIR/start_slice.sh"
COMPLETE_SLICE_SCRIPT="$SCRIPT_DIR/complete_slice.sh"

usage() {
  cat <<'EOF'
Usage:
  resume_task.sh [--root /path/to/workspace] <task-slug>
EOF
}

POSITIONAL=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
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
PROJECT_CONTEXT_FILE="$ROOT_DIR/.campfire/project_context.json"
TASK_CONTEXT_FILE="$TASK_DIR/task_context.json"

if [ ! -d "$TASK_DIR" ]; then
  echo "Task not found: $TASK_DIR" >&2
  echo "If you intended to continue an existing task, stop and confirm the workspace root plus task slug." >&2
  echo "Do not bootstrap a replacement task from a resume request unless the user explicitly asked to create a new task." >&2
  exit 1
fi

echo "Task directory:"
echo "  $TASK_DIR"
echo

if [ -f "$PROJECT_CONTEXT_FILE" ]; then
  echo "Project context:"
  sed -n '1,120p' "$PROJECT_CONTEXT_FILE"
  echo
fi

if [ -f "$TASK_CONTEXT_FILE" ]; then
  echo "Task context:"
  sed -n '1,160p' "$TASK_CONTEXT_FILE"
  echo
fi

if [ -f "$TASK_DIR/checkpoints.json" ]; then
  echo "Checkpoint summary:"
  sed -n '1,120p' "$TASK_DIR/checkpoints.json"
  echo
fi

if [ -f "$TASK_DIR/checkpoints.json" ]; then
  echo "Execution policy:"
  python3 - "$TASK_DIR/checkpoints.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
execution = data.get("execution", {})
if not isinstance(execution, dict):
    execution = {}

mode = execution.get("mode", "single_milestone")
run_style = execution.get("run_style", "bounded")
auto_advance = execution.get("auto_advance", False)
auto_reframe = execution.get("auto_reframe", False)
planning_slice = execution.get("planning_slice_minutes", 15)
runtime_budget = execution.get("runtime_budget_minutes", 0)
min_runtime = execution.get("min_runtime_minutes", 0)
min_milestones = execution.get("min_milestones_per_run", 1)
max_milestones = execution.get("max_milestones_per_run", 1)
reframe_queue_below = execution.get("reframe_queue_below", 0)
target_queue_depth = execution.get("target_queue_depth", 0)
max_reframes_per_run = execution.get("max_reframes_per_run", 0)
continue_until = execution.get("continue_until", [])
queued = execution.get("queued_milestones", [])
notes = execution.get("notes", "")

runtime_budget_display = "unlimited" if mode == "rolling" and run_style == "until_stopped" and runtime_budget == 0 else runtime_budget
max_milestones_display = "unlimited" if mode == "rolling" and run_style == "until_stopped" and max_milestones == 0 else max_milestones
max_reframes_display = "unlimited" if mode == "rolling" and run_style == "until_stopped" and max_reframes_per_run == 0 else max_reframes_per_run

print(f"  mode: {mode}")
print(f"  run_style: {run_style}")
print(f"  auto_advance: {auto_advance}")
print(f"  auto_reframe: {auto_reframe}")
print(f"  planning_slice_minutes: {planning_slice}")
print(f"  runtime_budget_minutes: {runtime_budget_display}")
print(f"  min_runtime_minutes: {min_runtime}")
print(f"  min_milestones_per_run: {min_milestones}")
print(f"  max_milestones_per_run: {max_milestones_display}")
print(f"  reframe_queue_below: {reframe_queue_below}")
print(f"  target_queue_depth: {target_queue_depth}")
print(f"  max_reframes_per_run: {max_reframes_display}")
print(f"  continue_until: {continue_until}")
if queued:
    print("  queued_milestones:")
    for item in queued:
        if isinstance(item, dict):
            print(f"    - {item.get('milestone_id', '')}: {item.get('milestone_title', '')}")
if notes:
    print(f"  notes: {notes}")
PY
  echo
fi

if [ -f "$TASK_DIR/checkpoints.json" ]; then
  echo "Last run:"
  python3 - "$TASK_DIR/checkpoints.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
last_run = data.get("last_run", {})
if not isinstance(last_run, dict):
    last_run = {}

stop_reason = last_run.get("stop_reason", "")
summary = last_run.get("summary", "")
next_step = last_run.get("next_step", "")
events = last_run.get("events", [])
if not isinstance(events, list):
    events = []

print(f"  stop_reason: {stop_reason or 'unknown'}")
if events:
    print("  events:")
    for event in events:
        print(f"    - {event}")
if summary:
    print(f"  summary: {summary}")
if next_step:
    print(f"  next_step: {next_step}")
PY
  echo
fi

if [ -f "$TASK_DIR/checkpoints.json" ]; then
  echo "Workspace strategy:"
  python3 - "$TASK_DIR/checkpoints.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
workspace = data.get("workspace", {})
if not isinstance(workspace, dict):
    workspace = {}

strategy = workspace.get("strategy", "")
root = workspace.get("root", "")
git_root = workspace.get("git_root", "")
branch = workspace.get("branch", "")

print(f"  strategy: {strategy or 'unknown'}")
if root:
    print(f"  root: {root}")
if git_root:
    print(f"  git_root: {git_root}")
if branch:
    print(f"  branch: {branch}")
PY
  echo
fi

if [ -f "$TASK_DIR/runbook.md" ]; then
  echo "Runbook:"
  sed -n '1,120p' "$TASK_DIR/runbook.md"
  echo
fi

if [ -f "$TASK_DIR/handoff.md" ]; then
  echo "Handoff:"
  sed -n '1,120p' "$TASK_DIR/handoff.md"
  echo
fi

if [ -f "$TASK_DIR/artifacts.json" ]; then
  echo "Artifact manifest:"
  sed -n '1,120p' "$TASK_DIR/artifacts.json"
  echo
fi

if [ -f "$TASK_DIR/progress.md" ]; then
  echo "Recent progress:"
  tail -n 20 "$TASK_DIR/progress.md"
  echo
fi

echo "Recommended Codex App prompt:"
echo "  $("$PROMPT_TEMPLATE_SCRIPT" --root "$ROOT_DIR" --task-slug "$TASK_SLUG" resume)"

TASK_MODE="$(python3 - "$TASK_DIR/checkpoints.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
execution = data.get("execution", {})
if isinstance(execution, dict):
    print(execution.get("mode", "single_milestone"))
else:
    print("single_milestone")
PY
)"

if [ "$TASK_MODE" = "rolling" ]; then
  echo
  echo "Suggested monitor sidecar:"
  echo "  ./scripts/monitor_task_loop.sh $TASK_SLUG"
  echo "  Keep it observer-only and let it write only .campfire/monitoring/ artifacts."
fi

echo
echo "Pre-edit slice activation:"
python3 - "$TASK_DIR/checkpoints.json" "$TASK_SLUG" "$ROOT_DIR" "$START_SLICE_SCRIPT" <<'PY'
import json
import os
import sys
from pathlib import Path

path = Path(sys.argv[1])
task_slug = sys.argv[2]
root_dir = sys.argv[3]
start_slice_script = sys.argv[4]
data = json.loads(path.read_text())
status = data.get("status", "")
current = data.get("current", {})
execution = data.get("execution", {})

def normalize_queue(raw_queue):
    if not isinstance(raw_queue, list):
        return []
    normalized = []
    for item in raw_queue:
        if isinstance(item, dict):
            milestone_id = str(item.get("milestone_id", "")).strip()
            milestone_title = str(item.get("milestone_title", "")).strip()
        elif isinstance(item, str):
            text = item.strip()
            if ":" in text:
                milestone_id, milestone_title = text.split(":", 1)
                milestone_id = milestone_id.strip()
                milestone_title = milestone_title.strip()
            else:
                milestone_id = text
                milestone_title = text
        else:
            continue
        if milestone_id:
            normalized.append((milestone_id, milestone_title))
    return normalized

queue = normalize_queue(execution.get("queued_milestones", []))
if status == "in_progress":
    milestone_id = str(current.get("milestone_id", "")).strip() or "current"
    slice_id = str(current.get("slice_id", "")).strip() or "current-slice"
    slice_title = str(current.get("slice_title", "")).strip() or "Describe the current slice"
    print(f"  Task already active on `{milestone_id}` / `{slice_id}`.")
    print(f"  Continue using the persisted slice: {slice_title}")
elif queue:
    print(
        f"  {start_slice_script} --root {root_dir} --from-next "
        f"--slice-title \"Describe the next concrete slice\" {task_slug}"
    )
else:
    milestone_id = str(current.get("milestone_id", "")).strip()
    milestone_title = str(current.get("milestone_title", "")).strip() or milestone_id
    if milestone_id:
        print(
            f"  {start_slice_script} --root {root_dir} "
            f"--milestone-id {milestone_id} --milestone-title \"{milestone_title}\" "
            f"--slice-title \"Describe the next concrete slice\" {task_slug}"
        )
    else:
        print("  No active or queued milestone is available yet. Frame one before implementation.")
PY

echo
echo "Post-slice completion:"
echo "  $COMPLETE_SLICE_SCRIPT --root $ROOT_DIR --summary \"Describe what validated.\" --next-step \"Describe the next step.\" $TASK_SLUG"

if [ -f "$TASK_DIR/checkpoints.json" ] && [ -x "$AUTOMATION_HELPER_SCRIPT" ]; then
  if [ "$TASK_MODE" = "rolling" ]; then
    echo
    echo "Automation prompt variants:"
    "$AUTOMATION_HELPER_SCRIPT" --root "$ROOT_DIR" "$TASK_SLUG"
    if [ -x "$AUTOMATION_PROPOSAL_HELPER_SCRIPT" ]; then
      echo
      echo "Automation proposal metadata:"
      "$AUTOMATION_PROPOSAL_HELPER_SCRIPT" --root "$ROOT_DIR" "$TASK_SLUG"
    fi
    if [ -x "$AUTOMATION_SCHEDULE_SCAFFOLD_SCRIPT" ]; then
      echo
      echo "Automation schedule scaffolds:"
      "$AUTOMATION_SCHEDULE_SCAFFOLD_SCRIPT" --root "$ROOT_DIR" "$TASK_SLUG"
    fi
  fi
fi
