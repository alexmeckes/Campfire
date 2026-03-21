#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
ENABLE_SCRIPT="$SKILL_DIR/scripts/enable_rolling_mode.sh"
HELPER_SCRIPT="$SKILL_DIR/scripts/prompt_template_helper.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_prompt_template_helper.sh"

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

echo "== Prompt template helper simulation =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_prompt_bootstrap.out /tmp/campfire_prompt_resume.out /tmp/campfire_prompt_retro.out /tmp/campfire_prompt_bench.out /tmp/campfire_prompt_promote.out /tmp/campfire_prompt_bounded.out /tmp/campfire_prompt_until.out' EXIT

TASK_SLUG="verify-prompt-template"
TASK_ROOT=".tasks"
TASK_DIR="$TEMP_WORKSPACE/$TASK_ROOT/$TASK_SLUG"
cat >"$TEMP_WORKSPACE/campfire.toml" <<'EOF'
version = 1
project_name = "Prompt Template Verifier"
default_task_root = ".tasks"
EOF
"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify prompt template helper coverage" >/tmp/campfire_prompt_bootstrap.out
expect_file "$TASK_DIR/checkpoints.json"

"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" --task-slug "$TASK_SLUG" task_bootstrap >/tmp/campfire_prompt_bootstrap.out
expect_contains /tmp/campfire_prompt_bootstrap.out 'Use $task-framer, $long-horizon-worker, and $task-handoff-state'
expect_contains /tmp/campfire_prompt_bootstrap.out ".tasks/$TASK_SLUG/"
expect_contains /tmp/campfire_prompt_bootstrap.out 'first dependency-safe slice'

"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" --task-slug "$TASK_SLUG" resume >/tmp/campfire_prompt_resume.out
expect_contains /tmp/campfire_prompt_resume.out 'Use $long-horizon-worker and $task-handoff-state'
expect_not_contains /tmp/campfire_prompt_resume.out 'configured run budget'

"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" --task-slug "$TASK_SLUG" retrospective >/tmp/campfire_prompt_retro.out
expect_contains /tmp/campfire_prompt_retro.out 'Use $task-retrospector and $task-handoff-state'
expect_contains /tmp/campfire_prompt_retro.out 'record a structured improvement candidate'

"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" benchmark >/tmp/campfire_prompt_bench.out
expect_contains /tmp/campfire_prompt_bench.out 'benchmarks/campfire-bench/'
expect_contains /tmp/campfire_prompt_bench.out 'state fidelity'

"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" --task-slug "$TASK_SLUG" --candidate-id "slice-start-guard" improvement_promotion >/tmp/campfire_prompt_promote.out
expect_contains /tmp/campfire_prompt_promote.out 'promoted improvement candidate `slice-start-guard`'
expect_contains /tmp/campfire_prompt_promote.out 'keep the work local-first plus verifier-backed'

BOUNDED_SLUG="verify-prompt-template-bounded"
"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$BOUNDED_SLUG" "verify bounded prompt template coverage" >/tmp/campfire_prompt_bounded.out
"$ENABLE_SCRIPT" \
  --root "$TEMP_WORKSPACE" \
  --queue "milestone-002:Cover the bounded rolling prompt" \
  --queue "milestone-003:Refresh the bounded rolling queue" \
  "$BOUNDED_SLUG" >/tmp/campfire_prompt_bounded.out
"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" --task-slug "$BOUNDED_SLUG" resume >/tmp/campfire_prompt_bounded.out
expect_contains /tmp/campfire_prompt_bounded.out 'budget remains'
expect_contains /tmp/campfire_prompt_bounded.out 'configured run budget'
expect_contains /tmp/campfire_prompt_bounded.out '$thread-monitor-sidecar'
expect_contains /tmp/campfire_prompt_bounded.out './scripts/monitor_task_loop.sh'
expect_contains /tmp/campfire_prompt_bounded.out "task slug \`$BOUNDED_SLUG\`"
expect_contains /tmp/campfire_prompt_bounded.out 'retarget that same sidecar'

UNTIL_SLUG="verify-prompt-template-until"
"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$UNTIL_SLUG" "verify until-stopped prompt template coverage" >/tmp/campfire_prompt_until.out
"$ENABLE_SCRIPT" \
  --root "$TEMP_WORKSPACE" \
  --until-stopped \
  --queue "milestone-002:Cover the until-stopped rolling prompt" \
  --queue "milestone-003:Refresh the until-stopped rolling queue" \
  "$UNTIL_SLUG" >/tmp/campfire_prompt_until.out
"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" --task-slug "$UNTIL_SLUG" rolling_resume >/tmp/campfire_prompt_until.out
expect_contains /tmp/campfire_prompt_until.out 'safe-work exhaustion'
expect_contains /tmp/campfire_prompt_until.out 'Do not impose an internal runtime budget or milestone cap.'
expect_contains /tmp/campfire_prompt_until.out '$thread-monitor-sidecar'
expect_contains /tmp/campfire_prompt_until.out './scripts/monitor_task_loop.sh'
expect_contains /tmp/campfire_prompt_until.out "task slug \`$UNTIL_SLUG\`"
expect_contains /tmp/campfire_prompt_until.out 'retarget that same sidecar'
expect_not_contains /tmp/campfire_prompt_until.out 'configured run budget'

echo "PASS: Prompt template helper verification completed."
