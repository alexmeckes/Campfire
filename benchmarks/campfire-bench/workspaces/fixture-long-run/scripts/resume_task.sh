#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$HOME/.codex/skills}"
RESUME_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/resume_task.sh"
PROMPT_TEMPLATE_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/prompt_template_helper.sh"
FORWARD_ARGS=("$@")

if [ ! -x "$RESUME_SCRIPT" ]; then
  echo "Campfire resume script not found: $RESUME_SCRIPT" >&2
  echo "Set CAMPFIRE_SKILLS_ROOT or install Campfire skills with ./scripts/install_skills.sh." >&2
  exit 1
fi

if [ ! -x "$PROMPT_TEMPLATE_SCRIPT" ]; then
  echo "Campfire prompt template helper not found: $PROMPT_TEMPLATE_SCRIPT" >&2
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
echo "  $("$PROMPT_TEMPLATE_SCRIPT" --root "$ROOT_DIR" --task-slug "$TASK_SLUG" resume)"
