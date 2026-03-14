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
planning_slice = execution.get("planning_slice_minutes", 15)
runtime_budget = execution.get("runtime_budget_minutes", 0)
max_milestones = execution.get("max_milestones_per_run", 1)
continue_until = execution.get("continue_until", [])
queued = execution.get("queued_milestones", [])
notes = execution.get("notes", "")

print(f"  mode: {mode}")
print(f"  auto_advance: {auto_advance}")
print(f"  planning_slice_minutes: {planning_slice}")
print(f"  runtime_budget_minutes: {runtime_budget}")
print(f"  max_milestones_per_run: {max_milestones}")
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
    print(f"  Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue .autonomous/{task_slug}/. Keep planning bounded, auto-advance through queued milestones, and stop only on the configured run limits or a real blocker.")
else:
    print(f"  Use $long-horizon-worker and $task-handoff-state to continue .autonomous/{task_slug}/ from the current handoff and validate the next slice before stopping.")
PY
