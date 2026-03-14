#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
ENABLE_SCRIPT="$SKILL_DIR/scripts/enable_rolling_mode.sh"
HELPER_SCRIPT="$SKILL_DIR/scripts/automation_prompt_helper.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_automation_prompt_helper.sh"

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

expect_not_contains() {
  local path="$1"
  local pattern="$2"
  if /usr/bin/grep -Fq -- "$pattern" "$path"; then
    fail "Unexpected pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$INIT_SCRIPT" "$ENABLE_SCRIPT" "$HELPER_SCRIPT" "$SELF_SCRIPT"

echo "== Automation prompt helper simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_automation_helper.out /tmp/campfire_automation_verifier.out /tmp/campfire_automation_until.out' EXIT

BOUNDED_SLUG="verify-automation-helper"
BOUNDED_DIR="$TEMP_WORKSPACE/.autonomous/$BOUNDED_SLUG"
"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$BOUNDED_SLUG" "verify automation prompt helper bounded mode" >/tmp/campfire_automation_helper.out
expect_file "$BOUNDED_DIR/checkpoints.json"

"$ENABLE_SCRIPT" \
  --root "$TEMP_WORKSPACE" \
  --queue "milestone-002:Implement the second rolling slice" \
  --queue "milestone-003:Refresh the rolling backlog" \
  "$BOUNDED_SLUG" >/tmp/campfire_automation_helper.out

"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" "$BOUNDED_SLUG" >/tmp/campfire_automation_helper.out
expect_contains /tmp/campfire_automation_helper.out 'rolling_resume:'
expect_contains /tmp/campfire_automation_helper.out 'verifier_sweep:'
expect_contains /tmp/campfire_automation_helper.out 'backlog_refresh:'
expect_contains /tmp/campfire_automation_helper.out ".autonomous/$BOUNDED_SLUG/"
expect_contains /tmp/campfire_automation_helper.out 'budget remains'
expect_contains /tmp/campfire_automation_helper.out 'configured run budget'
expect_not_contains /tmp/campfire_automation_helper.out "$TEMP_WORKSPACE"
expect_not_contains /tmp/campfire_automation_helper.out 'schedule'
expect_not_contains /tmp/campfire_automation_helper.out 'workspace'

"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" --variant verifier_sweep "$BOUNDED_SLUG" >/tmp/campfire_automation_verifier.out
expect_contains /tmp/campfire_automation_verifier.out 'verifier_sweep:'
expect_not_contains /tmp/campfire_automation_verifier.out 'rolling_resume:'
expect_not_contains /tmp/campfire_automation_verifier.out 'backlog_refresh:'

UNTIL_SLUG="verify-automation-until-stopped"
UNTIL_DIR="$TEMP_WORKSPACE/.autonomous/$UNTIL_SLUG"
"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$UNTIL_SLUG" "verify automation prompt helper until-stopped mode" >/tmp/campfire_automation_until.out
expect_file "$UNTIL_DIR/checkpoints.json"

"$ENABLE_SCRIPT" \
  --root "$TEMP_WORKSPACE" \
  --until-stopped \
  --queue "milestone-002:Extend the until-stopped backlog" \
  --queue "milestone-003:Evaluate the manual-stop loop" \
  "$UNTIL_SLUG" >/tmp/campfire_automation_until.out

"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" --variant rolling_resume "$UNTIL_SLUG" >/tmp/campfire_automation_until.out
expect_contains /tmp/campfire_automation_until.out 'rolling_resume:'
expect_contains /tmp/campfire_automation_until.out 'safe-work exhaustion'
expect_contains /tmp/campfire_automation_until.out 'Do not impose an internal runtime budget or milestone cap.'
expect_not_contains /tmp/campfire_automation_until.out 'configured run budget'
expect_not_contains /tmp/campfire_automation_until.out "$TEMP_WORKSPACE"

echo "PASS: Automation prompt helper verification completed."
