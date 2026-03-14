#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"

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
TASK_DIR="$ROOT_DIR/.autonomous/$TASK_SLUG"

if [ ! -d "$TASK_DIR" ]; then
  echo "Task not found: $TASK_DIR" >&2
  exit 1
fi

echo "Task directory:"
echo "  $TASK_DIR"
echo

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

print(f"  mode: {mode}")
print(f"  auto_advance: {auto_advance}")
print(f"  auto_reframe: {auto_reframe}")
print(f"  planning_slice_minutes: {planning_slice}")
print(f"  runtime_budget_minutes: {runtime_budget}")
print(f"  min_runtime_minutes: {min_runtime}")
print(f"  min_milestones_per_run: {min_milestones}")
print(f"  max_milestones_per_run: {max_milestones}")
print(f"  reframe_queue_below: {reframe_queue_below}")
print(f"  target_queue_depth: {target_queue_depth}")
print(f"  max_reframes_per_run: {max_reframes_per_run}")
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
python3 - "$TASK_DIR/checkpoints.json" "$TASK_SLUG" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
task_slug = sys.argv[2]
data = json.loads(path.read_text())
execution = data.get("execution", {})
if isinstance(execution, dict) and execution.get("mode") == "rolling":
    print(f"  Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue .autonomous/{task_slug}/. Keep planning bounded, auto-advance through queued milestones, replenish the queue when policy allows and budget remains, do not self-pause before the configured minimum runtime and milestone floor unless a blocker or decision boundary appears, and stop only on the configured run limits or a real blocker.")
else:
    print(f"  Use $long-horizon-worker and $task-handoff-state to continue .autonomous/{task_slug}/ from the current handoff and validate the next slice before stopping.")
PY
