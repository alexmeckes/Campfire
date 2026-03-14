#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
ENABLE_SCRIPT="$SKILL_DIR/scripts/enable_rolling_mode.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_enable_rolling_mode.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_file() {
  local path="$1"
  [ -e "$path" ] || fail "Missing required path: $path"
}

expect_contains() {
  local path="$1"
  local pattern="$2"
  if ! /usr/bin/grep -q "$pattern" "$path"; then
    fail "Expected pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$INIT_SCRIPT" "$ENABLE_SCRIPT" "$RESUME_SCRIPT" "$SELF_SCRIPT"

echo "== Rolling mode helper simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_enable_init.out /tmp/campfire_enable_resume.out' EXIT
TASK_SLUG="verify-enable-rolling"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify the rolling-mode helper" >/tmp/campfire_enable_init.out

expect_file "$TASK_DIR/checkpoints.json"
expect_file "$TASK_DIR/handoff.md"

"$ENABLE_SCRIPT" \
  --root "$TEMP_WORKSPACE" \
  --planning-slice-minutes 8 \
  --runtime-budget-minutes 90 \
  --min-runtime-minutes 30 \
  --min-milestones-per-run 2 \
  --max-milestones-per-run 4 \
  --note "Converted by the helper for unattended Codex App work." \
  --queue "milestone-002:Implement the next rolling slice" \
  --queue "milestone-003:Wrap with documentation" \
  "$TASK_SLUG" >/tmp/campfire_enable_resume.out

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_enable_resume.out

expect_contains "$TASK_DIR/checkpoints.json" '"mode": "rolling"'
expect_contains "$TASK_DIR/checkpoints.json" '"run_style": "bounded"'
expect_contains "$TASK_DIR/checkpoints.json" '"planning_slice_minutes": 8'
expect_contains "$TASK_DIR/checkpoints.json" '"runtime_budget_minutes": 90'
expect_contains "$TASK_DIR/checkpoints.json" '"min_runtime_minutes": 30'
expect_contains "$TASK_DIR/checkpoints.json" '"min_milestones_per_run": 2'
expect_contains "$TASK_DIR/checkpoints.json" '"max_milestones_per_run": 4'
expect_contains "$TASK_DIR/checkpoints.json" '"auto_reframe": true'
expect_contains "$TASK_DIR/checkpoints.json" '"reframe_queue_below": 1'
expect_contains "$TASK_DIR/checkpoints.json" '"target_queue_depth": 5'
expect_contains "$TASK_DIR/checkpoints.json" '"max_reframes_per_run": 3'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_id": "milestone-002"'
expect_contains "$TASK_DIR/checkpoints.json" '"milestone_id": "milestone-003"'
expect_contains "$TASK_DIR/checkpoints.json" 'Converted by the helper for unattended Codex App work.'
if /usr/bin/grep -Fq -- '"manual_pause"' "$TASK_DIR/checkpoints.json"; then
  fail 'manual_pause should not be part of the helper default continue_until policy'
fi
expect_contains "$TASK_DIR/handoff.md" 'replenish the queue when policy allows and budget remains'
expect_contains "$TASK_DIR/handoff.md" 'do not self-pause before the configured minimum runtime and milestone floor'
expect_contains /tmp/campfire_enable_resume.out 'mode: rolling'
expect_contains /tmp/campfire_enable_resume.out 'run_style: bounded'
expect_contains /tmp/campfire_enable_resume.out 'auto_advance: True'
expect_contains /tmp/campfire_enable_resume.out 'auto_reframe: True'
expect_contains /tmp/campfire_enable_resume.out 'min_runtime_minutes: 30'
expect_contains /tmp/campfire_enable_resume.out 'min_milestones_per_run: 2'
expect_contains /tmp/campfire_enable_resume.out 'milestone-002: Implement the next rolling slice'
expect_contains /tmp/campfire_enable_resume.out 'do not self-pause before the configured minimum runtime and milestone floor'

echo "PASS: Rolling mode helper verification completed."
