#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_HELPER="$SCRIPT_DIR/campfire_sql.py"

usage() {
  cat <<'EOF'
Usage:
  doctor_task.sh [--root /path/to/workspace] <task-slug>
EOF
}

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
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 1
fi

ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
TASK_SLUG="$1"

python3 "$SQL_HELPER" doctor-task --root "$ROOT_DIR" "$TASK_SLUG"
