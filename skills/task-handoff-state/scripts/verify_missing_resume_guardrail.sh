#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
RESUME_SCRIPT="$ROOT_DIR/skills/task-handoff-state/scripts/resume_task.sh"
TASK_STATE_SKILL="$ROOT_DIR/skills/task-handoff-state/SKILL.md"
FRAMER_SKILL="$ROOT_DIR/skills/task-framer/SKILL.md"
WORKER_SKILL="$ROOT_DIR/skills/long-horizon-worker/SKILL.md"
README_FILE="$ROOT_DIR/README.md"
EXAMPLE_AGENTS="$ROOT_DIR/examples/basic-workspace/AGENTS.md"
SELF_SCRIPT="$ROOT_DIR/skills/task-handoff-state/scripts/verify_missing_resume_guardrail.sh"

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
zsh -n "$RESUME_SCRIPT" "$SELF_SCRIPT"

echo "== Missing resume simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_missing_resume.out' EXIT

if "$RESUME_SCRIPT" --root "$TEMP_WORKSPACE" missing-task >/tmp/campfire_missing_resume.out 2>&1; then
  fail "resume_task.sh should fail when the requested task is missing"
fi

expect_contains /tmp/campfire_missing_resume.out "Task not found:"
expect_contains /tmp/campfire_missing_resume.out "If you intended to continue an existing task, stop and confirm the workspace root plus task slug."
expect_contains /tmp/campfire_missing_resume.out "Do not bootstrap a replacement task from a resume request unless the user explicitly asked to create a new task."

expect_contains "$TASK_STATE_SKILL" 'If `resume_task.sh` reports that the task is missing, treat that as a stop condition for resume/continue requests.'
expect_contains "$TASK_STATE_SKILL" 'Do not silently create or bootstrap a replacement task.'
expect_contains "$FRAMER_SKILL" 'Do not use it to silently recover a missing resume target'
expect_contains "$FRAMER_SKILL" 'Stop and ask for the correct workspace/task instead of bootstrapping a replacement task.'
expect_contains "$WORKER_SKILL" 'for a continue or resume request against a named task, stop and report the missing task state instead of initializing a replacement'
expect_contains "$README_FILE" 'If `resume_task.sh` says the task is missing during a continue/resume request, stop and confirm the workspace plus task slug instead of bootstrapping a replacement task.'
expect_contains "$EXAMPLE_AGENTS" 'If a named `.autonomous/<task>/` is missing during a continue request, stop and confirm the workspace instead of creating a replacement task.'

echo "PASS: Missing resume guardrail verification completed."
