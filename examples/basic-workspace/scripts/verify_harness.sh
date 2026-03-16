#!/bin/zsh
set -euo pipefail

EXAMPLE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$HOME/.codex/skills}"
NEW_TASK_SCRIPT="$EXAMPLE_ROOT/scripts/new_task.sh"
RESUME_TASK_SCRIPT="$EXAMPLE_ROOT/scripts/resume_task.sh"
ENABLE_ROLLING_SCRIPT="$EXAMPLE_ROOT/scripts/enable_rolling_mode.sh"
AUTOMATION_PROMPTS_SCRIPT="$EXAMPLE_ROOT/scripts/automation_prompt_helper.sh"
DOCTOR_TASK_SCRIPT="$EXAMPLE_ROOT/scripts/doctor_task.sh"
TASK_SLUG="verify-example-wrapper-flow"

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
zsh -n "$NEW_TASK_SCRIPT" "$RESUME_TASK_SCRIPT" "$ENABLE_ROLLING_SCRIPT" "$AUTOMATION_PROMPTS_SCRIPT" "$DOCTOR_TASK_SCRIPT" "$EXAMPLE_ROOT/scripts/verify_harness.sh"

echo "== Skill presence =="
expect_file "$SKILLS_ROOT/task-handoff-state/SKILL.md"
expect_file "$SKILLS_ROOT/task-framer/SKILL.md"
expect_file "$SKILLS_ROOT/long-horizon-worker/SKILL.md"
expect_file "$SKILLS_ROOT/task-evaluator/SKILL.md"
expect_file "$SKILLS_ROOT/course-corrector/SKILL.md"

echo "== Temp workspace wrapper flow =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_example_new.out /tmp/campfire_example_roll.out /tmp/campfire_example_prompts.out /tmp/campfire_example_resume.out' EXIT
mkdir -p "$TEMP_WORKSPACE/scripts"
cp "$NEW_TASK_SCRIPT" "$RESUME_TASK_SCRIPT" "$ENABLE_ROLLING_SCRIPT" "$AUTOMATION_PROMPTS_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp "$DOCTOR_TASK_SCRIPT" "$TEMP_WORKSPACE/scripts/"
chmod +x "$TEMP_WORKSPACE"/scripts/*.sh

CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/new_task.sh" --slug "$TASK_SLUG" "verify example wrapper flow" >/tmp/campfire_example_new.out
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/enable_rolling_mode.sh" --until-stopped --queue "milestone-002:Next slice" --queue "milestone-003:Follow-up slice" "$TASK_SLUG" >/tmp/campfire_example_roll.out
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/automation_prompt_helper.sh" "$TASK_SLUG" >/tmp/campfire_example_prompts.out
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/resume_task.sh" "$TASK_SLUG" >/tmp/campfire_example_resume.out

expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/plan.md"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/runbook.md"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/progress.md"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/handoff.md"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/checkpoints.json"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/artifacts.json"
expect_file "$TEMP_WORKSPACE/.campfire/campfire.db"
expect_file "$TEMP_WORKSPACE/.campfire/registry.json"
expect_file "$TEMP_WORKSPACE/.campfire/project_context.json"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/task_context.json"
expect_contains "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/checkpoints.json" '"mode": "rolling"'
expect_contains "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/checkpoints.json" '"run_style": "until_stopped"'
expect_contains "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/handoff.md" 'Use $task-framer'
expect_contains /tmp/campfire_example_new.out 'Workspace-specific prompt:'
expect_contains /tmp/campfire_example_new.out 'To switch this task into rolling mode later:'
expect_contains /tmp/campfire_example_roll.out 'Workspace-local follow-ups:'
expect_contains /tmp/campfire_example_prompts.out 'rolling_resume:'
expect_contains /tmp/campfire_example_resume.out 'Workspace-specific prompt:'
expect_contains /tmp/campfire_example_resume.out 'Project context:'
expect_contains /tmp/campfire_example_resume.out 'Task context:'
expect_contains /tmp/campfire_example_resume.out 'Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state'

CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/doctor_task.sh" "$TASK_SLUG" >/tmp/campfire_example_doctor.out
expect_contains /tmp/campfire_example_doctor.out 'Doctor passed:'

echo "PASS: Example workspace wrapper verification completed."
