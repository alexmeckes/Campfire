#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$HOME/.codex/skills}"
ENABLE_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/enable_rolling_mode.sh"
FORWARD_ARGS=("$@")
POSITIONAL=()

if [ ! -x "$ENABLE_SCRIPT" ]; then
  echo "Campfire rolling-mode helper not found: $ENABLE_SCRIPT" >&2
  echo "Set CAMPFIRE_SKILLS_ROOT or install Campfire skills with ./scripts/install_skills.sh." >&2
  exit 1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      shift 2
      ;;
    --run-style|--planning-slice-minutes|--runtime-budget-minutes|--min-runtime-minutes|--min-milestones-per-run|--max-milestones-per-run|--auto-reframe|--reframe-queue-below|--target-queue-depth|--max-reframes-per-run|--continue-until|--note|--queue)
      shift 2
      ;;
    --until-stopped|--help|-h)
      POSITIONAL+=("$1")
      shift
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

TASK_SLUG="${POSITIONAL[-1]:-}"

"$ENABLE_SCRIPT" --root "$ROOT_DIR" "${FORWARD_ARGS[@]}"

if [ -n "$TASK_SLUG" ] && [ "$TASK_SLUG" != "--help" ] && [ "$TASK_SLUG" != "-h" ]; then
  echo
  echo "Workspace-local follow-ups:"
  echo "  ./scripts/resume_task.sh $TASK_SLUG"
  echo "  ./scripts/automation_prompt_helper.sh $TASK_SLUG"
fi
