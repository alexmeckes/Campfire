#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
ENABLE_ROLLING_SCRIPT="$SKILL_DIR/scripts/enable_rolling_mode.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"

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
zsh -n "$INIT_SCRIPT" "$ENABLE_ROLLING_SCRIPT" "$START_SLICE_SCRIPT" "$RESUME_SCRIPT"

echo "== Start-slice lifecycle =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_start_slice.out /tmp/campfire_start_resume.out' EXIT
TASK_SLUG="verify-start-slice"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify deterministic slice activation" >/dev/null
"$ENABLE_ROLLING_SCRIPT" --root "$TEMP_WORKSPACE" --until-stopped \
  --queue "milestone-002:Camp Loop" \
  --queue "milestone-003:Validate Loop" \
  "$TASK_SLUG" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --from-next \
  --slice-id "camp-ui-shell" \
  --slice-title "Build the camp UI shell" \
  --next-slice "Implement and validate the camp UI shell." \
  "$TASK_SLUG" >/tmp/campfire_start_slice.out
"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_start_resume.out

expect_contains "$TASK_DIR/checkpoints.json" '"status": "in_progress"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_id": "milestone-002"'
expect_contains "$TASK_DIR/checkpoints.json" '"slice_id": "camp-ui-shell"'
expect_contains "$TASK_DIR/checkpoints.json" '"slice_started"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_id": "milestone-003"'
expect_contains "$TASK_DIR/handoff.md" 'Status: in progress'
expect_contains "$TASK_DIR/handoff.md" 'Current milestone: `milestone-002` - Camp Loop'
expect_contains "$TASK_DIR/handoff.md" 'Next slice: Implement and validate the camp UI shell.'
expect_contains "$TASK_DIR/progress.md" 'Started `milestone-002` / `camp-ui-shell`.'
expect_contains /tmp/campfire_start_slice.out 'Activated task: verify-start-slice'
expect_contains /tmp/campfire_start_resume.out 'Current milestone: `milestone-002` - Camp Loop'

echo "PASS: Start-slice activation verification completed."
