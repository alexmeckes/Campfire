#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_HELPER="$SCRIPT_DIR/campfire_sql.py"

usage() {
  cat <<'EOF'
Usage:
  record_improvement_candidate.sh [--root /path/to/workspace] [--task-slug slug] \
    --category kind --scope scope --title "Title" --problem "Problem" \
    --next-action "Next action" [options]

Options:
  --candidate-id value
  --source-type value
  --source-milestone-id value
  --source-run-id value
  --why-not-script text
  --evidence path (repeatable)
  --trigger-pattern text (repeatable)
  --proposed-skill-name value
  --proposed-skill-purpose text
  --confidence low|medium|high
  --promotion-state proposed|drafted|trialing|promoted_repo_local|promoted_core|rejected|retired
  --promoted-task-slug value
  --output-path /custom/path.json
EOF
}

ARGS=()
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
      ARGS+=("$1")
      shift
      ;;
  esac
done

ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"

python3 "$SQL_HELPER" record-improvement-candidate --root "$ROOT_DIR" "${ARGS[@]}"
