#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$HOME/.codex/skills}"
BOOTSTRAP_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/bootstrap_task.sh"
PROMPT_TEMPLATE_SCRIPT="$SKILLS_ROOT/task-handoff-state/scripts/prompt_template_helper.sh"
FORWARD_ARGS=("$@")
TASK_SLUG=""

slugify() {
  local value
  value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')"
  printf '%s' "${value:-task}"
}

if [ ! -x "$BOOTSTRAP_SCRIPT" ]; then
  echo "Campfire bootstrap script not found: $BOOTSTRAP_SCRIPT" >&2
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
    --slug)
      TASK_SLUG="$2"
      shift 2
      ;;
    --help|-h)
      "$BOOTSTRAP_SCRIPT" --help
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [ "${#POSITIONAL[@]}" -lt 1 ]; then
  "$BOOTSTRAP_SCRIPT" --help >&2
  exit 1
fi

OBJECTIVE="${POSITIONAL[1]}"
TASK_SLUG="${TASK_SLUG:-$(slugify "$OBJECTIVE")}"

"$BOOTSTRAP_SCRIPT" --root "$ROOT_DIR" "${FORWARD_ARGS[@]}"

echo
echo "Workspace-specific prompt:"
echo "  $("$PROMPT_TEMPLATE_SCRIPT" --root "$ROOT_DIR" --task-slug "$TASK_SLUG" task_bootstrap)"
echo "  To switch this task into rolling mode later: ./scripts/enable_rolling_mode.sh --until-stopped $TASK_SLUG"
