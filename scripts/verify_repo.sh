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
  "$ROOT_DIR/scripts/new_task.sh" \
  "$ROOT_DIR/scripts/resume_task.sh" \
  "$ROOT_DIR/scripts/enable_rolling_mode.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/init_task.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/bootstrap_task.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/enable_rolling_mode.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/resume_task.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_task_lifecycle.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_blocked_retry.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_course_correction.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_task_evaluation.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_worktree_bootstrap.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_rolling_execution.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_rolling_reframe.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_budget_limit.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_waiting_on_decision.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_enable_rolling_mode.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_automation_patterns.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_autonomous_floor.sh" \
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
expect_file "$ROOT_DIR/skills/task-handoff-state/references/automation-patterns.md"
expect_file "$ROOT_DIR/skills/course-corrector/SKILL.md"
expect_file "$ROOT_DIR/skills/course-corrector/agents/openai.yaml"
expect_file "$ROOT_DIR/skills/course-corrector/references/course-correction-triggers.md"
expect_file "$ROOT_DIR/skills/task-evaluator/SKILL.md"
expect_file "$ROOT_DIR/skills/task-evaluator/agents/openai.yaml"
expect_file "$ROOT_DIR/skills/task-evaluator/references/evaluation-checklist.md"

echo "== Example workspace presence =="
expect_file "$ROOT_DIR/examples/basic-workspace/AGENTS.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/example-task/plan.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/example-task/runbook.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/example-task/progress.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/example-task/handoff.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/example-task/checkpoints.json"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/example-task/artifacts.json"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/rolling-task/plan.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/rolling-task/runbook.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/rolling-task/progress.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/rolling-task/handoff.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/rolling-task/checkpoints.json"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/rolling-task/artifacts.json"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/rolling-task/findings/rolling-queue.md"
expect_file "$ROOT_DIR/examples/basic-workspace/.autonomous/rolling-task/findings/automation-ready.md"

echo "== Installer dry run in temp CODEX_HOME =="
TEMP_CODEX_HOME="$(mktemp -d)"
trap 'rm -rf "$TEMP_CODEX_HOME"' EXIT
CODEX_HOME="$TEMP_CODEX_HOME" "$ROOT_DIR/scripts/install_skills.sh" >/tmp/campfire_install.out
expect_file "$TEMP_CODEX_HOME/skills/long-horizon-worker"
expect_file "$TEMP_CODEX_HOME/skills/task-handoff-state"
expect_file "$TEMP_CODEX_HOME/skills/task-evaluator"

echo "== Lifecycle verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_task_lifecycle.sh"

echo "== Blocked retry verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_blocked_retry.sh"

echo "== Course correction verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_course_correction.sh"

echo "== Task evaluation verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_task_evaluation.sh"

echo "== Worktree bootstrap verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_worktree_bootstrap.sh"

echo "== Rolling execution verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_rolling_execution.sh"

echo "== Rolling reframe verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_rolling_reframe.sh"

echo "== Rolling budget-limit verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_budget_limit.sh"

echo "== Rolling waiting-on-decision verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_waiting_on_decision.sh"

echo "== Rolling mode helper verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_enable_rolling_mode.sh"

echo "== Automation pattern verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_automation_patterns.sh"

echo "== Autonomous floor verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_autonomous_floor.sh"

rm -f /tmp/campfire_install.out

echo "PASS: Campfire repo verification completed."
