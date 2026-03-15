#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
COMPLETE_SLICE_SCRIPT="$SKILL_DIR/scripts/complete_slice.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_contains() {
  local path="$1"
  local pattern="$2"
  if ! /usr/bin/grep -q "$pattern" "$path"; then
    fail "Expected pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$INIT_SCRIPT" "$START_SLICE_SCRIPT" "$COMPLETE_SLICE_SCRIPT"

echo "== Complete-slice lifecycle =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_complete_slice.out' EXIT
TASK_SLUG="verify-complete-slice"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify deterministic slice completion" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --milestone-id "milestone-001" \
  --milestone-title "Deterministic completion" \
  --slice-id "validation-pass" \
  --slice-title "Validate the first deterministic slice" \
  --next-slice "Write the evaluation note." \
  "$TASK_SLUG" >/dev/null
"$COMPLETE_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" \
  --status validated \
  --summary "Validated the deterministic completion slice." \
  --next-step "Frame the next milestone." \
  --next-slice "Frame milestone-002." \
  --event milestone_validated \
  "$TASK_SLUG" >/tmp/campfire_complete_slice.out

expect_contains "$TASK_DIR/checkpoints.json" '"status": "validated"'
expect_contains "$TASK_DIR/checkpoints.json" '"stop_reason": "milestone_validated"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_validated"'
expect_contains "$TASK_DIR/checkpoints.json" '"slice_completed"'
expect_contains "$TASK_DIR/handoff.md" 'Status: validated'
expect_contains "$TASK_DIR/handoff.md" 'Next slice: Frame milestone-002.'
expect_contains "$TASK_DIR/progress.md" 'Completed `milestone-001` / `validation-pass` with status `validated`.'
expect_contains "$TASK_DIR/heartbeat.json" '"state": "idle"'
expect_contains "$TASK_DIR/logs/session.log" '"state": "idle"'
expect_contains "$TEMP_WORKSPACE/.campfire/registry.json" "\"task_slug\": \"$TASK_SLUG\""
expect_contains "$TEMP_WORKSPACE/.campfire/registry.json" '"status": "validated"'
expect_contains /tmp/campfire_complete_slice.out 'Completed task: verify-complete-slice'

echo "PASS: Complete-slice verification completed."
