#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_HELPER="$SCRIPT_DIR/campfire_sql.py"

usage() {
  cat <<'EOF'
Usage:
  refresh_registry.sh [--root /path/to/workspace]
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
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"

python3 "$SQL_HELPER" sync-all --root "$ROOT_DIR" >/dev/null
python3 "$SQL_HELPER" render-projections --root "$ROOT_DIR" >/dev/null
python3 "$SQL_HELPER" render-registry --root "$ROOT_DIR"
