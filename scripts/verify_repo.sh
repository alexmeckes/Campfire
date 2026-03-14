#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_file() {
  local path="$1"
  [ -e "$path" ] || fail "Missing required path: $path"
}

echo "== Syntax checks =="
zsh -n \
  "$ROOT_DIR/skills/task-handoff-state/scripts/init_task.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/resume_task.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_task_lifecycle.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_blocked_retry.sh" \
  "$ROOT_DIR/scripts/install_skills.sh"

echo "== Skill presence =="
expect_file "$ROOT_DIR/skills/long-horizon-worker/SKILL.md"
expect_file "$ROOT_DIR/skills/long-horizon-worker/agents/openai.yaml"
expect_file "$ROOT_DIR/skills/task-framer/SKILL.md"
expect_file "$ROOT_DIR/skills/task-framer/agents/openai.yaml"
expect_file "$ROOT_DIR/skills/task-framer/references/framing-checklist.md"
expect_file "$ROOT_DIR/skills/task-handoff-state/SKILL.md"
expect_file "$ROOT_DIR/skills/task-handoff-state/agents/openai.yaml"
expect_file "$ROOT_DIR/skills/task-handoff-state/references/task-state-contract.md"
expect_file "$ROOT_DIR/skills/course-corrector/SKILL.md"
expect_file "$ROOT_DIR/skills/course-corrector/agents/openai.yaml"
expect_file "$ROOT_DIR/skills/course-corrector/references/course-correction-triggers.md"

echo "== Example workspace presence =="
expect_file "$ROOT_DIR/examples/basic-workspace/AGENTS.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/example-task/plan.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/example-task/runbook.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/example-task/progress.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/example-task/handoff.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/example-task/checkpoints.json"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/example-task/artifacts.json"

echo "== Installer dry run in temp CODEX_HOME =="
TEMP_CODEX_HOME="$(mktemp -d)"
trap 'rm -rf "$TEMP_CODEX_HOME"' EXIT
CODEX_HOME="$TEMP_CODEX_HOME" "$ROOT_DIR/scripts/install_skills.sh" >/tmp/campfire_install.out
expect_file "$TEMP_CODEX_HOME/skills/long-horizon-worker"
expect_file "$TEMP_CODEX_HOME/skills/task-handoff-state"

echo "== Lifecycle verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_task_lifecycle.sh"

echo "== Blocked retry verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_blocked_retry.sh"

rm -f /tmp/campfire_install.out

echo "PASS: Campfire repo verification completed."
