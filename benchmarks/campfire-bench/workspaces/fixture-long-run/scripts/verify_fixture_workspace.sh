#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TASK_SLUG="fixture-long-run"
INVENTORY="$ROOT_DIR/benchmark/inventory.json"

[ -f "$ROOT_DIR/benchmark/brief.md" ] || { echo "Missing benchmark brief" >&2; exit 1; }
[ -f "$ROOT_DIR/benchmark/validation-checklist.md" ] || { echo "Missing validation checklist" >&2; exit 1; }
[ -f "$INVENTORY" ] || { echo "Missing benchmark inventory" >&2; exit 1; }

python3 - "$ROOT_DIR" "$INVENTORY" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
inventory = json.loads(Path(sys.argv[2]).read_text())
if inventory.get("workspace_name") != "fixture-long-run":
    raise SystemExit("workspace_name mismatch")
if inventory.get("task_slug") != "fixture-long-run":
    raise SystemExit("task_slug mismatch")
phases = inventory.get("phases", [])
if len(phases) < 5:
    raise SystemExit("expected at least 5 phases")
for phase in phases:
    artifact = root / phase["artifact"]
    if not artifact.exists():
        raise SystemExit(f"missing artifact placeholder: {artifact}")
decision = inventory.get("decision_boundary", {})
if decision.get("status") != "pending":
    raise SystemExit("decision boundary should start pending")
PY

if [ -n "${CAMPFIRE_SKILLS_ROOT:-}" ]; then
  "$ROOT_DIR/scripts/doctor_task.sh" "$TASK_SLUG" >/dev/null
  "$ROOT_DIR/scripts/resume_task.sh" "$TASK_SLUG" >/tmp/fixture_long_resume.out
  /usr/bin/grep -Fq "Task context:" /tmp/fixture_long_resume.out || { echo "resume output missing task context" >&2; exit 1; }
fi

echo "PASS: Fixture long-run workspace verification completed."
