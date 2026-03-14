#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
ENABLE_SCRIPT="$SKILL_DIR/scripts/enable_rolling_mode.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
HELPER_SCRIPT="$SKILL_DIR/scripts/automation_prompt_helper.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_resume_automation_prompt_guidance.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_contains() {
  local path="$1"
  local pattern="$2"
  if ! /usr/bin/grep -Fq -- "$pattern" "$path"; then
    fail "Expected pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$INIT_SCRIPT" "$ENABLE_SCRIPT" "$RESUME_SCRIPT" "$HELPER_SCRIPT" "$SELF_SCRIPT"

echo "== Resume automation guidance simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_resume_automation.out' EXIT
TASK_SLUG="verify-resume-automation-guidance"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify resume automation guidance" >/tmp/campfire_resume_automation.out

"$ENABLE_SCRIPT" \
  --root "$TEMP_WORKSPACE" \
  --until-stopped \
  --queue "milestone-002:Extend the automation-helper backlog" \
  --queue "milestone-003:Evaluate the resume guidance output" \
  "$TASK_SLUG" >/tmp/campfire_resume_automation.out

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_resume_automation.out

expect_contains /tmp/campfire_resume_automation.out 'Automation prompt variants:'
expect_contains /tmp/campfire_resume_automation.out 'rolling_resume:'
expect_contains /tmp/campfire_resume_automation.out 'verifier_sweep:'
expect_contains /tmp/campfire_resume_automation.out 'backlog_refresh:'
expect_contains /tmp/campfire_resume_automation.out ".autonomous/$TASK_SLUG/"
expect_contains /tmp/campfire_resume_automation.out 'safe-work exhaustion'
expect_contains /tmp/campfire_resume_automation.out 'Do not impose an internal runtime budget or milestone cap.'

echo "PASS: Resume automation guidance verification completed."
