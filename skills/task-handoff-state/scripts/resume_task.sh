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
echo "  Use \$long-horizon-worker and \$task-handoff-state to continue .autonomous/$TASK_SLUG/ from the current handoff and validate the next slice before stopping."
