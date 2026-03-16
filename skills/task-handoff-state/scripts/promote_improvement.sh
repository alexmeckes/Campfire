#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
PROMOTION_STATE="promoted_repo_local"
PROMOTED_TASK_SLUG=""
TASK_OBJECTIVE=""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_HELPER="$SCRIPT_DIR/campfire_sql.py"
INIT_SCRIPT="$SCRIPT_DIR/init_task.sh"
REFRESH_REGISTRY_SCRIPT="$SCRIPT_DIR/refresh_registry.sh"

usage() {
  cat <<'EOF'
Usage:
  promote_improvement.sh [--root /path/to/workspace] [--promotion-state state] \
    [--task-slug slug] [--task-objective "Objective"] <candidate-id>
EOF
}

slugify() {
  local value
  value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')"
  printf '%s' "${value:-task}"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --promotion-state)
      PROMOTION_STATE="$2"
      shift 2
      ;;
    --task-slug)
      PROMOTED_TASK_SLUG="$2"
      shift 2
      ;;
    --task-objective)
      TASK_OBJECTIVE="$2"
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
CANDIDATE_ID="$1"

TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT
python3 "$SQL_HELPER" show-improvement-candidate --root "$ROOT_DIR" "$CANDIDATE_ID" > "$TMP_JSON"

eval "$(python3 - "$TMP_JSON" <<'PY'
import json
import shlex
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())

title = str(data.get("title", "")).strip()
next_action = str(data.get("next_action", "")).strip()
category = str(data.get("category", "")).strip()
source = data.get("source", {})
if not isinstance(source, dict):
    source = {}
source_task_slug = str(source.get("task_slug", "")).strip()
source_milestone_id = str(source.get("milestone_id", "")).strip()
problem = str(data.get("problem", "")).strip()

for key, value in {
    "CANDIDATE_TITLE": title,
    "CANDIDATE_NEXT_ACTION": next_action,
    "CANDIDATE_CATEGORY": category,
    "SOURCE_TASK_SLUG": source_task_slug,
    "SOURCE_MILESTONE_ID": source_milestone_id,
    "CANDIDATE_PROBLEM": problem,
}.items():
    print(f"{key}={shlex.quote(value)}")
PY
)"

if [ -z "$PROMOTED_TASK_SLUG" ]; then
  PROMOTED_TASK_SLUG="$(slugify "improve-$CANDIDATE_ID")"
fi

if [ -z "$TASK_OBJECTIVE" ]; then
  TASK_OBJECTIVE="Address improvement candidate: $CANDIDATE_TITLE"
  if [ -n "$CANDIDATE_NEXT_ACTION" ]; then
    TASK_OBJECTIVE="$TASK_OBJECTIVE. $CANDIDATE_NEXT_ACTION"
  fi
fi

"$INIT_SCRIPT" --root "$ROOT_DIR" --slug "$PROMOTED_TASK_SLUG" "$TASK_OBJECTIVE" >/dev/null

PLAN_FILE="$ROOT_DIR/.autonomous/$PROMOTED_TASK_SLUG/plan.md"
PROGRESS_FILE="$ROOT_DIR/.autonomous/$PROMOTED_TASK_SLUG/progress.md"
HANDOFF_FILE="$ROOT_DIR/.autonomous/$PROMOTED_TASK_SLUG/handoff.md"

cat >> "$PLAN_FILE" <<EOF

## Improvement Source

- Candidate ID: $CANDIDATE_ID
- Category: $CANDIDATE_CATEGORY
- Source task: ${SOURCE_TASK_SLUG:-none}
- Source milestone: ${SOURCE_MILESTONE_ID:-none}
- Problem: $CANDIDATE_PROBLEM
- Next action: $CANDIDATE_NEXT_ACTION
EOF

cat >> "$PROGRESS_FILE" <<EOF
- Improvement candidate promoted: $CANDIDATE_ID
- Source task: ${SOURCE_TASK_SLUG:-none}
- Next slice: turn the candidate into a concrete, validated Campfire improvement.
EOF

cat >> "$HANDOFF_FILE" <<EOF

## Improvement Source

- Candidate ID: $CANDIDATE_ID
- Source task: ${SOURCE_TASK_SLUG:-none}
- Candidate next action: $CANDIDATE_NEXT_ACTION
EOF

python3 "$SQL_HELPER" promote-improvement-candidate \
  --root "$ROOT_DIR" \
  --promotion-state "$PROMOTION_STATE" \
  --promoted-task-slug "$PROMOTED_TASK_SLUG" \
  "$CANDIDATE_ID" >/dev/null

"$REFRESH_REGISTRY_SCRIPT" --root "$ROOT_DIR" >/dev/null

cat <<EOF
Promoted improvement candidate:
  candidate_id: $CANDIDATE_ID
  promotion_state: $PROMOTION_STATE
  task_slug: $PROMOTED_TASK_SLUG
  objective: $TASK_OBJECTIVE
EOF
