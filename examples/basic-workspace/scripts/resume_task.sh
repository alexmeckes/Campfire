#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$HOME/.codex/skills}"
RESUME_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/resume_task.sh"
FORWARD_ARGS=("$@")

if [ ! -x "$RESUME_SCRIPT" ]; then
  echo "Campfire resume script not found: $RESUME_SCRIPT" >&2
  echo "Set CAMPFIRE_SKILLS_ROOT or install Campfire skills with ./scripts/install_skills.sh." >&2
  exit 1
fi

POSITIONAL=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      shift 2
      ;;
    --help|-h)
      "$RESUME_SCRIPT" --help
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [ "${#POSITIONAL[@]}" -ne 1 ]; then
  "$RESUME_SCRIPT" --help >&2
  exit 1
fi

TASK_SLUG="${POSITIONAL[1]}"

"$RESUME_SCRIPT" --root "$ROOT_DIR" "${FORWARD_ARGS[@]}"

echo
echo "Workspace-specific prompt:"
python3 - "$ROOT_DIR/.autonomous/$TASK_SLUG/checkpoints.json" "$TASK_SLUG" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
task_slug = sys.argv[2]
data = json.loads(path.read_text())
execution = data.get("execution", {})

if isinstance(execution, dict) and execution.get("mode") == "rolling":
    if execution.get("run_style") == "until_stopped":
        prompt = (
            f"  Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and "
            f"$task-handoff-state to continue .autonomous/{task_slug}/. Keep planning bounded, auto-advance "
            f"through queued milestones, replenish the queue when policy allows, and keep going until a real "
            f"blocker, decision boundary, safe-work exhaustion, or an external manual pause appears. Do not "
            f"impose an internal runtime budget or milestone cap."
        )
    else:
        prompt = (
            f"  Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and "
            f"$task-handoff-state to continue .autonomous/{task_slug}/. Keep planning bounded, auto-advance "
            f"through queued milestones, replenish the queue when policy allows and budget remains, do not "
            f"self-pause before the configured minimum runtime and milestone floor unless a blocker or decision "
            f"boundary appears, and stop only on a real blocker, decision boundary, budget limit, or an external "
            f"manual pause."
        )
else:
    prompt = (
        f"  Use $long-horizon-worker and $task-handoff-state to continue .autonomous/{task_slug}/ from the current "
        f"handoff and validate the next slice before stopping."
    )

print(prompt)
PY
