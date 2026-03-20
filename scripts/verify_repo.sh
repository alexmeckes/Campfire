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
  "$ROOT_DIR/scripts/verify_benchmark.sh" \
  "$ROOT_DIR/scripts/doctor_task.sh" \
  "$ROOT_DIR/scripts/record_improvement_candidate.sh" \
  "$ROOT_DIR/scripts/promote_improvement.sh" \
  "$ROOT_DIR/scripts/prompt_template_helper.sh" \
  "$ROOT_DIR/scripts/queue_guidance.sh" \
  "$ROOT_DIR/scripts/draft_generated_skill.sh" \
  "$ROOT_DIR/scripts/monitor_task.sh" \
  "$ROOT_DIR/scripts/monitor_task_loop.sh" \
  "$ROOT_DIR/scripts/automation_proposal_helper.sh" \
  "$ROOT_DIR/scripts/automation_schedule_scaffold.sh" \
  "$ROOT_DIR/scripts/start_slice.sh" \
  "$ROOT_DIR/scripts/complete_slice.sh" \
  "$ROOT_DIR/scripts/refresh_registry.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/doctor_task.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/new_task.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/resume_task.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/enable_rolling_mode.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/automation_prompt_helper.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/automation_proposal_helper.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/automation_schedule_scaffold.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/prompt_template_helper.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/queue_guidance.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/record_improvement_candidate.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/promote_improvement.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/draft_generated_skill.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/monitor_task.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/monitor_task_loop.sh" \
  "$ROOT_DIR/examples/basic-workspace/scripts/verify_harness.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/init_task.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/bootstrap_task.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/enable_rolling_mode.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/resume_task.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/doctor_task.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/record_improvement_candidate.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/promote_improvement.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/prompt_template_helper.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/queue_guidance.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/draft_generated_skill.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/monitor_task.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/monitor_task_loop.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/start_slice.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/complete_slice.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/touch_heartbeat.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/refresh_registry.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_task_lifecycle.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_start_slice.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_complete_slice.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_registry_refresh.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_sql_control_plane.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_improvement_flow.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_skill_inventory.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_session_lineage.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_draft_generated_skill.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_monitor_task.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_monitor_task_loop.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_automation_proposal_helper.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_automation_schedule_scaffold.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_blocked_retry.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_course_correction.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_task_evaluation.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_worktree_bootstrap.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_rolling_execution.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_rolling_reframe.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_budget_limit.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_waiting_on_decision.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_enable_rolling_mode.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_missing_resume_guardrail.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_prompt_template_helper.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_automation_patterns.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_automation_prompt_helper.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_resume_automation_proposal_guidance.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_resume_automation_schedule_guidance.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_guidance_queue.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_autonomous_floor.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_until_stopped_mode.sh" \
  "$ROOT_DIR/skills/task-handoff-state/scripts/verify_resume_automation_prompt_guidance.sh" \
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
expect_file "$ROOT_DIR/skills/task-handoff-state/references/prompt-templates.md"
expect_file "$ROOT_DIR/skills/task-handoff-state/templates/prompt_templates.json"
expect_file "$ROOT_DIR/skills/course-corrector/SKILL.md"
expect_file "$ROOT_DIR/skills/course-corrector/agents/openai.yaml"
expect_file "$ROOT_DIR/skills/course-corrector/references/course-correction-triggers.md"
expect_file "$ROOT_DIR/skills/task-evaluator/SKILL.md"
expect_file "$ROOT_DIR/skills/task-evaluator/agents/openai.yaml"
expect_file "$ROOT_DIR/skills/task-evaluator/references/evaluation-checklist.md"
expect_file "$ROOT_DIR/skills/task-retrospector/SKILL.md"
expect_file "$ROOT_DIR/skills/task-retrospector/agents/openai.yaml"
expect_file "$ROOT_DIR/skills/task-retrospector/references/retrospective-checklist.md"

echo "== Example workspace presence =="
expect_file "$ROOT_DIR/campfire.toml"
expect_file "$ROOT_DIR/examples/basic-workspace/AGENTS.md"
expect_file "$ROOT_DIR/examples/basic-workspace/campfire.toml"
expect_file "$ROOT_DIR/examples/basic-workspace/README.md"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/doctor_task.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/new_task.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/resume_task.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/enable_rolling_mode.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/automation_prompt_helper.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/automation_proposal_helper.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/automation_schedule_scaffold.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/prompt_template_helper.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/queue_guidance.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/record_improvement_candidate.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/promote_improvement.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/draft_generated_skill.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/monitor_task.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/monitor_task_loop.sh"
expect_file "$ROOT_DIR/examples/basic-workspace/scripts/verify_harness.sh"
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
expect_file "$ROOT_DIR/benchmarks/campfire-bench/README.md"
expect_file "$ROOT_DIR/benchmarks/campfire-bench/scenarios/resume-after-interrupt.json"
expect_file "$ROOT_DIR/benchmarks/campfire-bench/scenarios/blocked-then-unblock.json"
expect_file "$ROOT_DIR/benchmarks/campfire-bench/scenarios/queue-replenish.json"
expect_file "$ROOT_DIR/benchmarks/campfire-bench/scenarios/state-drift-detection.json"
expect_file "$ROOT_DIR/benchmarks/campfire-bench/scenarios/repo-medium-validation.json"
expect_file "$ROOT_DIR/benchmarks/campfire-bench/fixtures/results/sample-resume-after-interrupt.json"
expect_file "$ROOT_DIR/scripts/run_campfire_bench.py"
expect_file "$ROOT_DIR/docs/campfire-bench.md"
expect_file "$ROOT_DIR/docs/campfire-generated-skills.md"

echo "== Example workspace wrapper verifier =="
CAMPFIRE_SKILLS_ROOT="$ROOT_DIR/skills" "$ROOT_DIR/examples/basic-workspace/scripts/verify_harness.sh"

echo "== Installer dry run in temp CODEX_HOME =="
TEMP_CODEX_HOME="$(mktemp -d)"
trap 'rm -rf "$TEMP_CODEX_HOME"' EXIT
CODEX_HOME="$TEMP_CODEX_HOME" "$ROOT_DIR/scripts/install_skills.sh" >/tmp/campfire_install.out
expect_file "$TEMP_CODEX_HOME/skills/long-horizon-worker"
expect_file "$TEMP_CODEX_HOME/skills/task-handoff-state"
expect_file "$TEMP_CODEX_HOME/skills/task-evaluator"

echo "== Lifecycle verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_task_lifecycle.sh"

echo "== Start-slice verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_start_slice.sh"

echo "== Complete-slice verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_complete_slice.sh"

echo "== Registry refresh verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_registry_refresh.sh"

echo "== SQL control-plane verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_sql_control_plane.sh"

echo "== Improvement flow verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_improvement_flow.sh"

echo "== Skill inventory verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_skill_inventory.sh"

echo "== Session lineage verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_session_lineage.sh"

echo "== Draft generated skill verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_draft_generated_skill.sh"

echo "== Monitor task verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_monitor_task.sh"

echo "== Monitor loop verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_monitor_task_loop.sh"

echo "== Automation proposal helper verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_automation_proposal_helper.sh"

echo "== Automation schedule scaffold verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_automation_schedule_scaffold.sh"

echo "== Benchmark verifier =="
"$ROOT_DIR/scripts/verify_benchmark.sh"

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

echo "== Missing resume guardrail verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_missing_resume_guardrail.sh"

echo "== Prompt template helper verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_prompt_template_helper.sh"

echo "== Automation pattern verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_automation_patterns.sh"

echo "== Automation prompt helper verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_automation_prompt_helper.sh"

echo "== Guidance queue verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_guidance_queue.sh"

echo "== Autonomous floor verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_autonomous_floor.sh"

echo "== Until-stopped verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_until_stopped_mode.sh"

echo "== Resume automation-guidance verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_resume_automation_prompt_guidance.sh"

echo "== Resume automation-proposal verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_resume_automation_proposal_guidance.sh"

echo "== Resume automation-schedule verifier =="
"$ROOT_DIR/skills/task-handoff-state/scripts/verify_resume_automation_schedule_guidance.sh"

rm -f /tmp/campfire_install.out

echo "PASS: Campfire repo verification completed."
