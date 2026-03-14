#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
ENABLE_SCRIPT="$SKILL_DIR/scripts/enable_rolling_mode.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_until_stopped_mode.sh"

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

echo "== Until-stopped rolling simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_until_init.out /tmp/campfire_until_resume.out' EXIT
TASK_SLUG="verify-until-stopped"
TASK_DIR="$TEMP_WORKSPACE/.autonomous/$TASK_SLUG"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify the until-stopped rolling style" >/tmp/campfire_until_init.out

expect_file "$TASK_DIR/checkpoints.json"
expect_file "$TASK_DIR/handoff.md"

"$ENABLE_SCRIPT" \
  --root "$TEMP_WORKSPACE" \
  --until-stopped \
  --queue "milestone-002:Extend the backlog automatically" \
  --queue "milestone-003:Validate the manual-stop policy" \
  "$TASK_SLUG" >/tmp/campfire_until_resume.out

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_until_resume.out

expect_contains "$TASK_DIR/checkpoints.json" '"mode": "rolling"'
expect_contains "$TASK_DIR/checkpoints.json" '"run_style": "until_stopped"'
expect_contains "$TASK_DIR/checkpoints.json" '"runtime_budget_minutes": 0'
expect_contains "$TASK_DIR/checkpoints.json" '"min_runtime_minutes": 0'
expect_contains "$TASK_DIR/checkpoints.json" '"min_milestones_per_run": 0'
expect_contains "$TASK_DIR/checkpoints.json" '"max_milestones_per_run": 0'
expect_contains "$TASK_DIR/checkpoints.json" '"max_reframes_per_run": 0'
expect_contains "$TASK_DIR/checkpoints.json" '"continue_until": ['
expect_contains "$TASK_DIR/checkpoints.json" '"blocked"'
expect_contains "$TASK_DIR/checkpoints.json" '"waiting_on_decision"'
if /usr/bin/grep -Fq -- '"budget_limit"' "$TASK_DIR/checkpoints.json"; then
  fail 'budget_limit should not be part of the until-stopped continue_until policy'
fi
if /usr/bin/grep -Fq -- '"manual_pause"' "$TASK_DIR/checkpoints.json"; then
  fail 'manual_pause should remain external-only in until-stopped mode'
fi
expect_contains "$TASK_DIR/handoff.md" 'keep going until a real blocker, decision boundary, safe-work exhaustion, or an external manual pause appears'
expect_contains "$TASK_DIR/handoff.md" 'Do not impose an internal runtime budget or milestone cap'
expect_contains /tmp/campfire_until_resume.out 'run_style: until_stopped'
expect_contains /tmp/campfire_until_resume.out 'runtime_budget_minutes: unlimited'
expect_contains /tmp/campfire_until_resume.out 'max_milestones_per_run: unlimited'
expect_contains /tmp/campfire_until_resume.out 'max_reframes_per_run: unlimited'
expect_contains /tmp/campfire_until_resume.out 'keep going until a real blocker, decision boundary, safe-work exhaustion, or an external manual pause appears'

echo "PASS: Until-stopped rolling verification completed."
