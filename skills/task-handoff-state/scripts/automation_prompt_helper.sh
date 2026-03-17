#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_HELPER="${SQL_HELPER:-$SCRIPT_DIR/campfire_sql.py}"
PROMPT_TEMPLATE_SCRIPT="$SCRIPT_DIR/prompt_template_helper.sh"

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
TASK_ROOT="$(python3 "$SQL_HELPER" show-project --root "$ROOT_DIR" --field task_root)"
TASK_DIR="$ROOT_DIR/$TASK_ROOT/$TASK_SLUG"
CHECKPOINT_FILE="$TASK_DIR/checkpoints.json"

if [ ! -d "$TASK_DIR" ]; then
  echo "Task not found: $TASK_DIR" >&2
  exit 1
fi

if [ ! -f "$CHECKPOINT_FILE" ]; then
  echo "Missing checkpoints.json: $CHECKPOINT_FILE" >&2
  exit 1
fi

if [ ! -x "$PROMPT_TEMPLATE_SCRIPT" ]; then
  echo "Missing prompt template helper: $PROMPT_TEMPLATE_SCRIPT" >&2
  exit 1
fi

selected=("${VARIANTS[@]}")
if [ "${#selected[@]}" -eq 0 ]; then
  selected=("rolling_resume" "verifier_sweep" "backlog_refresh")
fi

for variant in "${selected[@]}"; do
  case "$variant" in
    rolling_resume|verifier_sweep|backlog_refresh)
      ;;
    *)
      echo "Unknown variant: $variant" >&2
      exit 1
      ;;
  esac
done

index=0
for variant in "${selected[@]}"; do
  index=$((index + 1))
  if [ "$index" -gt 1 ]; then
    echo
  fi
  echo "${variant}:"
  prompt="$("$PROMPT_TEMPLATE_SCRIPT" --root "$ROOT_DIR" --task-slug "$TASK_SLUG" "$variant")"
  echo "  $prompt"
done
