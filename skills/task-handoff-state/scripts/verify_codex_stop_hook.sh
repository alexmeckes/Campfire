#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL_DIR="$ROOT_DIR/skills/task-handoff-state"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
ENABLE_SCRIPT="$SKILL_DIR/scripts/enable_rolling_mode.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
COMPLETE_SLICE_SCRIPT="$SKILL_DIR/scripts/complete_slice.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_codex_stop_hook.sh"
TASK_SLUG="verify-codex-stop-hook"

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

expect_empty() {
  local path="$1"
  if [ -s "$path" ]; then
    fail "Expected empty output in $path"
  fi
}

TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_codex_hook_continue.out /tmp/campfire_codex_hook_waiting.out /tmp/campfire_codex_hook_reentrant.out /tmp/campfire_codex_hook_session.out /tmp/campfire_codex_hook_prompt.out /tmp/campfire_codex_hook_post.out' EXIT

mkdir -p "$TEMP_WORKSPACE/scripts" "$TEMP_WORKSPACE/.codex/hooks"
cp "$ROOT_DIR/scripts/monitor_task.sh" "$ROOT_DIR/scripts/prompt_template_helper.sh" "$TEMP_WORKSPACE/scripts/"
cp "$ROOT_DIR/.codex/config.toml" "$ROOT_DIR/.codex/hooks.json" "$TEMP_WORKSPACE/.codex/"
cp "$ROOT_DIR/.codex/hooks/campfire-stop.sh" "$ROOT_DIR/.codex/hooks/campfire-session-start.sh" "$ROOT_DIR/.codex/hooks/campfire-post-tool.sh" "$ROOT_DIR/.codex/hooks/campfire-user-prompt-submit.sh" "$TEMP_WORKSPACE/.codex/hooks/"
chmod +x "$TEMP_WORKSPACE/scripts/"*.sh "$TEMP_WORKSPACE/.codex/hooks/"*.sh

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify the Codex Stop hook adapter" >/dev/null
"$ENABLE_SCRIPT" --root "$TEMP_WORKSPACE" --until-stopped --queue "milestone-002:Continue the rolling backlog" "$TASK_SLUG" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --from-next --slice-title "Verify healthy rolling continuation" "$TASK_SLUG" >/dev/null

printf '%s\n' "{\"hook_event_name\":\"SessionStart\",\"source\":\"resume\",\"cwd\":\"$TEMP_WORKSPACE\",\"session_id\":\"session-0\"}" | \
  CAMPFIRE_SKILLS_ROOT="$ROOT_DIR/skills" "$TEMP_WORKSPACE/.codex/hooks/campfire-session-start.sh" >/tmp/campfire_codex_hook_session.out

expect_contains /tmp/campfire_codex_hook_session.out '"hookEventName": "SessionStart"'
expect_contains /tmp/campfire_codex_hook_session.out 'Campfire project detected.'
expect_contains /tmp/campfire_codex_hook_session.out "$TASK_SLUG"

printf '%s\n' "{\"hook_event_name\":\"PostToolUse\",\"cwd\":\"$TEMP_WORKSPACE\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo ok\"},\"tool_use_id\":\"tool-1\",\"turn_id\":\"turn-0\",\"session_id\":\"session-0\"}" | \
  CAMPFIRE_SKILLS_ROOT="$ROOT_DIR/skills" "$TEMP_WORKSPACE/.codex/hooks/campfire-post-tool.sh" >/tmp/campfire_codex_hook_post.out

expect_empty /tmp/campfire_codex_hook_post.out
expect_contains "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/heartbeat.json" '"source": "codex-post-tool.sh"'

printf '%s\n' "{\"hook_event_name\":\"Stop\",\"cwd\":\"$TEMP_WORKSPACE\",\"stop_hook_active\":false,\"turn_id\":\"turn-1\",\"session_id\":\"session-1\"}" | \
  CAMPFIRE_SKILLS_ROOT="$ROOT_DIR/skills" "$TEMP_WORKSPACE/.codex/hooks/campfire-stop.sh" >/tmp/campfire_codex_hook_continue.out

expect_contains /tmp/campfire_codex_hook_continue.out '"decision": "block"'
expect_contains /tmp/campfire_codex_hook_continue.out "$TASK_SLUG"
expect_contains /tmp/campfire_codex_hook_continue.out 'Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, $task-handoff-state, and $thread-monitor-sidecar'

"$COMPLETE_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --status waiting_on_decision --summary "Pause on an explicit decision boundary." --next-step "Wait for the operator decision." "$TASK_SLUG" >/dev/null

printf '%s\n' "{\"hook_event_name\":\"UserPromptSubmit\",\"cwd\":\"$TEMP_WORKSPACE\",\"turn_id\":\"turn-1\",\"session_id\":\"session-1\",\"prompt\":\"continue the task\"}" | \
  CAMPFIRE_SKILLS_ROOT="$ROOT_DIR/skills" "$TEMP_WORKSPACE/.codex/hooks/campfire-user-prompt-submit.sh" >/tmp/campfire_codex_hook_prompt.out

expect_contains /tmp/campfire_codex_hook_prompt.out '"hookEventName": "UserPromptSubmit"'
expect_contains /tmp/campfire_codex_hook_prompt.out 'waiting_on_decision'
expect_contains /tmp/campfire_codex_hook_prompt.out 'Do not guess past the unresolved decision boundary'

printf '%s\n' "{\"hook_event_name\":\"Stop\",\"cwd\":\"$TEMP_WORKSPACE\",\"stop_hook_active\":false,\"turn_id\":\"turn-2\",\"session_id\":\"session-2\"}" | \
  CAMPFIRE_SKILLS_ROOT="$ROOT_DIR/skills" "$TEMP_WORKSPACE/.codex/hooks/campfire-stop.sh" >/tmp/campfire_codex_hook_waiting.out

expect_empty /tmp/campfire_codex_hook_waiting.out

printf '%s\n' "{\"hook_event_name\":\"Stop\",\"cwd\":\"$TEMP_WORKSPACE\",\"stop_hook_active\":true,\"turn_id\":\"turn-3\",\"session_id\":\"session-3\"}" | \
  CAMPFIRE_SKILLS_ROOT="$ROOT_DIR/skills" "$TEMP_WORKSPACE/.codex/hooks/campfire-stop.sh" >/tmp/campfire_codex_hook_reentrant.out

expect_empty /tmp/campfire_codex_hook_reentrant.out
expect_contains "$TEMP_WORKSPACE/.codex/hooks.json" '"SessionStart"'
expect_contains "$TEMP_WORKSPACE/.codex/hooks.json" '"PostToolUse"'
expect_contains "$TEMP_WORKSPACE/.codex/hooks.json" '"UserPromptSubmit"'
expect_contains "$TEMP_WORKSPACE/.codex/hooks.json" '"Stop"'
expect_contains "$TEMP_WORKSPACE/.codex/config.toml" 'codex_hooks = true'

echo "PASS: Codex hook verification completed."
