#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
SELF_SCRIPT="$ROOT_DIR/skills/task-handoff-state/scripts/verify_automation_patterns.sh"
REFERENCE="$ROOT_DIR/skills/task-handoff-state/references/automation-patterns.md"
README_FILE="$ROOT_DIR/README.md"
EXAMPLE_AGENTS="$ROOT_DIR/examples/basic-workspace/AGENTS.md"
EXAMPLE_FINDING="$ROOT_DIR/examples/basic-workspace/.autonomous/rolling-task/findings/automation-ready.md"

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
zsh -n "$SELF_SCRIPT"

echo "== Automation pattern coverage =="
expect_file "$REFERENCE"
expect_file "$README_FILE"
expect_file "$EXAMPLE_AGENTS"
expect_file "$EXAMPLE_FINDING"

expect_contains "$REFERENCE" "# Recurring Automation Patterns"
expect_contains "$REFERENCE" "Keep schedule and workspace outside the prompt."
expect_contains "$REFERENCE" "Nightly Rolling Resume"
expect_contains "$REFERENCE" "Verifier Sweep"
expect_contains "$REFERENCE" "Weekly Backlog Refresh"
expect_contains "$REFERENCE" 'If the task is `waiting_on_decision`, do not guess past the decision boundary.'

expect_contains "$README_FILE" "## Recurring Automation Patterns"
expect_contains "$README_FILE" "Automations are best when the task already has stable Campfire state and a known task slug."
expect_contains "$README_FILE" "Nightly rolling resume"
expect_contains "$README_FILE" "Verifier sweep"

expect_contains "$EXAMPLE_AGENTS" "For recurring Codex App automations, keep prompts task-only and let the automation own schedule plus workspace selection."
expect_contains "$EXAMPLE_FINDING" "Nightly rolling resume"
expect_contains "$EXAMPLE_FINDING" ".autonomous/rolling-task/"

echo "PASS: Automation pattern verification completed."
