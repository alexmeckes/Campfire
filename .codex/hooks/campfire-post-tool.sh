#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"
IMPL="$REPO_ROOT/skills/task-handoff-state/scripts/codex_stop_hook.py"

if [ ! -f "$IMPL" ]; then
  SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-${CODEX_HOME:-$HOME/.codex}/skills}"
  IMPL="$SKILLS_ROOT/task-handoff-state/scripts/codex_stop_hook.py"
fi

exec "$PYTHON_BIN" "$IMPL" --root "$REPO_ROOT"
