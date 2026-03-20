#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
ENABLE_SCRIPT="$SKILL_DIR/scripts/enable_rolling_mode.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_resume_automation_schedule_guidance.sh"

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

expect_not_contains() {
  local path="$1"
  local pattern="$2"
  if /usr/bin/grep -Fq -- "$pattern" "$path"; then
    fail "Did not expect pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$INIT_SCRIPT" "$ENABLE_SCRIPT" "$START_SLICE_SCRIPT" "$RESUME_SCRIPT" "$SELF_SCRIPT"

echo "== Resume automation schedule guidance simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_resume_automation_schedule.out' EXIT
TASK_SLUG="verify-resume-automation-schedule-guidance"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify resume automation schedule guidance" >/tmp/campfire_resume_automation_schedule.out

"$ENABLE_SCRIPT" \
  --root "$TEMP_WORKSPACE" \
  --until-stopped \
  --queue "milestone-002:Extend the automation cadence backlog" \
  --queue "milestone-003:Evaluate the resume schedule guidance output" \
  "$TASK_SLUG" >/tmp/campfire_resume_automation_schedule.out

"$START_SLICE_SCRIPT" \
  --root "$TEMP_WORKSPACE" \
  --milestone-id "milestone-001" \
  --milestone-title "Verify resume automation schedule guidance" \
  --slice-id "slice-001-resume-automation-schedules" \
  --slice-title "Inspect rolling resume schedule guidance" \
  "$TASK_SLUG" >/tmp/campfire_resume_automation_schedule.out

"$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" "$TASK_SLUG" >/tmp/campfire_resume_automation_schedule.out

expect_contains /tmp/campfire_resume_automation_schedule.out 'Automation prompt variants:'
expect_contains /tmp/campfire_resume_automation_schedule.out 'Automation proposal metadata:'
expect_contains /tmp/campfire_resume_automation_schedule.out 'Automation schedule scaffolds:'
expect_contains /tmp/campfire_resume_automation_schedule.out 'cadence_label: Nightly rolling resume'
expect_contains /tmp/campfire_resume_automation_schedule.out 'platform_scope: generic'
expect_contains /tmp/campfire_resume_automation_schedule.out 'run_style: until_stopped'
expect_contains /tmp/campfire_resume_automation_schedule.out 'current_milestone: milestone-001 - Verify resume automation schedule guidance'
expect_contains /tmp/campfire_resume_automation_schedule.out 'current_slice: slice-001-resume-automation-schedules - Inspect rolling resume schedule guidance'
expect_contains /tmp/campfire_resume_automation_schedule.out "$TEMP_WORKSPACE"
expect_not_contains /tmp/campfire_resume_automation_schedule.out 'RRULE'
expect_not_contains /tmp/campfire_resume_automation_schedule.out 'FREQ='
expect_not_contains /tmp/campfire_resume_automation_schedule.out '::automation-update'

echo "PASS: Resume automation schedule guidance verification completed."
