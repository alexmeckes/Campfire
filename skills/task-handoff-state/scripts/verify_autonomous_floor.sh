#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
ENABLE_SCRIPT="$SKILL_DIR/scripts/enable_rolling_mode.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_autonomous_floor.sh"

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
  if ! /usr/bin/grep -Fq -- "$pattern" "$path"; then
    fail "Expected pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$INIT_SCRIPT" "$ENABLE_SCRIPT" "$RESUME_SCRIPT" "$SELF_SCRIPT"

echo "== Autonomous floor simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_floor_init.out /tmp/campfire_floor_resume.out' EXIT
TASK_SLUG="verify-autonomous-floor"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify the autonomous rolling floor" >/tmp/campfire_floor_init.out

expect_file "$TASK_DIR/checkpoints.json"
expect_file "$TASK_DIR/handoff.md"

"$ENABLE_SCRIPT" \
  --root "$TEMP_WORKSPACE" \
  --queue "milestone-002:Extend the rolling backlog" \
  --queue "milestone-003:Validate the longer run policy" \
  "$TASK_SLUG" >/tmp/campfire_floor_resume.out

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_floor_resume.out

expect_contains "$TASK_DIR/checkpoints.json" '"mode": "rolling"'
expect_contains "$TASK_DIR/checkpoints.json" '"run_style": "bounded"'
expect_contains "$TASK_DIR/checkpoints.json" '"min_runtime_minutes": 60'
expect_contains "$TASK_DIR/checkpoints.json" '"min_milestones_per_run": 5'
expect_contains "$TASK_DIR/checkpoints.json" '"max_milestones_per_run": 8'
expect_contains "$TASK_DIR/checkpoints.json" '"target_queue_depth": 5'
expect_contains "$TASK_DIR/checkpoints.json" '"max_reframes_per_run": 3'
expect_contains "$TASK_DIR/checkpoints.json" '"continue_until": ['
expect_contains "$TASK_DIR/checkpoints.json" '"budget_limit"'
if /usr/bin/grep -Fq -- '"manual_pause"' "$TASK_DIR/checkpoints.json"; then
  fail 'manual_pause should not be part of the default autonomous continue_until policy'
fi
expect_contains "$TASK_DIR/handoff.md" 'do not self-pause before the configured minimum runtime and milestone floor'
expect_contains /tmp/campfire_floor_resume.out 'min_runtime_minutes: 60'
expect_contains /tmp/campfire_floor_resume.out 'run_style: bounded'
expect_contains /tmp/campfire_floor_resume.out 'min_milestones_per_run: 5'
expect_contains /tmp/campfire_floor_resume.out 'max_milestones_per_run: 8'
expect_contains /tmp/campfire_floor_resume.out 'target_queue_depth: 5'
expect_contains /tmp/campfire_floor_resume.out 'max_reframes_per_run: 3'
expect_contains /tmp/campfire_floor_resume.out 'do not self-pause before the configured minimum runtime and milestone floor'

echo "PASS: Autonomous floor verification completed."
