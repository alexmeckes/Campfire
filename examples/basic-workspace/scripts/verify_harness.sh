#!/bin/zsh
set -euo pipefail

EXAMPLE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$HOME/.codex/skills}"
NEW_TASK_SCRIPT="$EXAMPLE_ROOT/scripts/new_task.sh"
RESUME_TASK_SCRIPT="$EXAMPLE_ROOT/scripts/resume_task.sh"
ENABLE_ROLLING_SCRIPT="$EXAMPLE_ROOT/scripts/enable_rolling_mode.sh"
AUTOMATION_PROMPTS_SCRIPT="$EXAMPLE_ROOT/scripts/automation_prompt_helper.sh"
AUTOMATION_PROPOSAL_SCRIPT="$EXAMPLE_ROOT/scripts/automation_proposal_helper.sh"
AUTOMATION_SCHEDULE_SCRIPT="$EXAMPLE_ROOT/scripts/automation_schedule_scaffold.sh"
PROMPT_TEMPLATE_SCRIPT="$EXAMPLE_ROOT/scripts/prompt_template_helper.sh"
QUEUE_GUIDANCE_SCRIPT="$EXAMPLE_ROOT/scripts/queue_guidance.sh"
DOCTOR_TASK_SCRIPT="$EXAMPLE_ROOT/scripts/doctor_task.sh"
RECORD_IMPROVEMENT_SCRIPT="$EXAMPLE_ROOT/scripts/record_improvement_candidate.sh"
PROMOTE_IMPROVEMENT_SCRIPT="$EXAMPLE_ROOT/scripts/promote_improvement.sh"
DRAFT_SKILL_SCRIPT="$EXAMPLE_ROOT/scripts/draft_generated_skill.sh"
MONITOR_TASK_SCRIPT="$EXAMPLE_ROOT/scripts/monitor_task.sh"
MONITOR_TASK_LOOP_SCRIPT="$EXAMPLE_ROOT/scripts/monitor_task_loop.sh"
CODEX_CONFIG_FILE="$EXAMPLE_ROOT/.codex/config.toml"
CODEX_HOOKS_FILE="$EXAMPLE_ROOT/.codex/hooks.json"
CODEX_SESSION_START_HOOK="$EXAMPLE_ROOT/.codex/hooks/campfire-session-start.sh"
CODEX_POST_TOOL_HOOK="$EXAMPLE_ROOT/.codex/hooks/campfire-post-tool.sh"
CODEX_USER_PROMPT_HOOK="$EXAMPLE_ROOT/.codex/hooks/campfire-user-prompt-submit.sh"
CODEX_STOP_HOOK="$EXAMPLE_ROOT/.codex/hooks/campfire-stop.sh"
CLAUDE_SETTINGS_FILE="$EXAMPLE_ROOT/.claude/settings.json"
CLAUDE_RESUME_COMMAND="$EXAMPLE_ROOT/.claude/commands/campfire-resume.md"
CLAUDE_NEW_TASK_COMMAND="$EXAMPLE_ROOT/.claude/commands/campfire-new-task.md"
CLAUDE_START_SLICE_COMMAND="$EXAMPLE_ROOT/.claude/commands/campfire-start-slice.md"
CLAUDE_COMPLETE_SLICE_COMMAND="$EXAMPLE_ROOT/.claude/commands/campfire-complete-slice.md"
CLAUDE_HOOK_HELPER="$EXAMPLE_ROOT/.claude/hooks/campfire-hook-helper.py"
CLAUDE_SESSION_START_HOOK="$EXAMPLE_ROOT/.claude/hooks/campfire-session-start.sh"
CLAUDE_PRE_TOOL_HOOK="$EXAMPLE_ROOT/.claude/hooks/campfire-pre-tool.sh"
CLAUDE_POST_TOOL_HOOK="$EXAMPLE_ROOT/.claude/hooks/campfire-post-tool.sh"
CLAUDE_STATUSLINE_HOOK="$EXAMPLE_ROOT/.claude/hooks/campfire-statusline.sh"
TASK_SLUG="verify-example-wrapper-flow"
MONITOR_LOOP_PID=""

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
zsh -n "$NEW_TASK_SCRIPT" "$RESUME_TASK_SCRIPT" "$ENABLE_ROLLING_SCRIPT" "$AUTOMATION_PROMPTS_SCRIPT" "$AUTOMATION_PROPOSAL_SCRIPT" "$AUTOMATION_SCHEDULE_SCRIPT" "$PROMPT_TEMPLATE_SCRIPT" "$QUEUE_GUIDANCE_SCRIPT" "$DOCTOR_TASK_SCRIPT" "$RECORD_IMPROVEMENT_SCRIPT" "$PROMOTE_IMPROVEMENT_SCRIPT" "$DRAFT_SKILL_SCRIPT" "$MONITOR_TASK_SCRIPT" "$MONITOR_TASK_LOOP_SCRIPT" "$CODEX_SESSION_START_HOOK" "$CODEX_POST_TOOL_HOOK" "$CODEX_USER_PROMPT_HOOK" "$CODEX_STOP_HOOK" "$CLAUDE_SESSION_START_HOOK" "$CLAUDE_PRE_TOOL_HOOK" "$CLAUDE_POST_TOOL_HOOK" "$CLAUDE_STATUSLINE_HOOK" "$EXAMPLE_ROOT/scripts/verify_harness.sh"
python3 -m py_compile "$CLAUDE_HOOK_HELPER"

echo "== Skill presence =="
expect_file "$SKILLS_ROOT/task-handoff-state/SKILL.md"
expect_file "$SKILLS_ROOT/task-framer/SKILL.md"
expect_file "$SKILLS_ROOT/long-horizon-worker/SKILL.md"
expect_file "$SKILLS_ROOT/task-evaluator/SKILL.md"
expect_file "$SKILLS_ROOT/course-corrector/SKILL.md"

echo "== Temp workspace wrapper flow =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'if [ -n "${MONITOR_LOOP_PID:-}" ]; then kill "$MONITOR_LOOP_PID" >/dev/null 2>&1 || true; wait "$MONITOR_LOOP_PID" >/dev/null 2>&1 || true; fi; rm -rf "$TEMP_WORKSPACE" /tmp/campfire_example_new.out /tmp/campfire_example_roll.out /tmp/campfire_example_prompts.out /tmp/campfire_example_proposals.json /tmp/campfire_example_schedule.json /tmp/campfire_example_template.out /tmp/campfire_example_guidance.out /tmp/campfire_example_resume.out /tmp/campfire_example_monitor_loop.out /tmp/campfire_example_codex_session.out /tmp/campfire_example_codex_post.out /tmp/campfire_example_codex_prompt.out /tmp/campfire_example_codex_stop.out /tmp/campfire_example_claude_post_again.out' EXIT
mkdir -p "$TEMP_WORKSPACE/scripts"
cp "$NEW_TASK_SCRIPT" "$RESUME_TASK_SCRIPT" "$ENABLE_ROLLING_SCRIPT" "$AUTOMATION_PROMPTS_SCRIPT" "$AUTOMATION_PROPOSAL_SCRIPT" "$AUTOMATION_SCHEDULE_SCRIPT" "$PROMPT_TEMPLATE_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp "$QUEUE_GUIDANCE_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp "$DOCTOR_TASK_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp "$RECORD_IMPROVEMENT_SCRIPT" "$PROMOTE_IMPROVEMENT_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp "$DRAFT_SKILL_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp "$MONITOR_TASK_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp "$MONITOR_TASK_LOOP_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp -R "$EXAMPLE_ROOT/.codex" "$TEMP_WORKSPACE/"
cp -R "$EXAMPLE_ROOT/.claude" "$TEMP_WORKSPACE/"
chmod +x "$TEMP_WORKSPACE"/scripts/*.sh
chmod +x "$TEMP_WORKSPACE/.codex/hooks/"*.sh
chmod +x "$TEMP_WORKSPACE/.claude/hooks/"*.sh

CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/new_task.sh" --slug "$TASK_SLUG" "verify example wrapper flow" >/tmp/campfire_example_new.out
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/enable_rolling_mode.sh" --until-stopped --queue "milestone-002:Next slice" --queue "milestone-003:Follow-up slice" "$TASK_SLUG" >/tmp/campfire_example_roll.out
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/automation_prompt_helper.sh" "$TASK_SLUG" >/tmp/campfire_example_prompts.out
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/automation_proposal_helper.sh" --json "$TASK_SLUG" >/tmp/campfire_example_proposals.json
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/automation_schedule_scaffold.sh" --json "$TASK_SLUG" >/tmp/campfire_example_schedule.json
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/prompt_template_helper.sh" --task-slug "$TASK_SLUG" resume >/tmp/campfire_example_template.out
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/queue_guidance.sh" --mode next_boundary --summary "Pause for review at the next boundary." "$TASK_SLUG" >/tmp/campfire_example_guidance.out
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
expect_file "$TEMP_WORKSPACE/.campfire/improvement_backlog.json"
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/task_context.json"
expect_file "$TEMP_WORKSPACE/.codex/config.toml"
expect_file "$TEMP_WORKSPACE/.codex/hooks.json"
expect_file "$TEMP_WORKSPACE/.codex/hooks/campfire-session-start.sh"
expect_file "$TEMP_WORKSPACE/.codex/hooks/campfire-post-tool.sh"
expect_file "$TEMP_WORKSPACE/.codex/hooks/campfire-user-prompt-submit.sh"
expect_file "$TEMP_WORKSPACE/.codex/hooks/campfire-stop.sh"
expect_file "$TEMP_WORKSPACE/.claude/settings.json"
expect_file "$TEMP_WORKSPACE/.claude/commands/campfire-resume.md"
expect_file "$TEMP_WORKSPACE/.claude/commands/campfire-new-task.md"
expect_file "$TEMP_WORKSPACE/.claude/commands/campfire-start-slice.md"
expect_file "$TEMP_WORKSPACE/.claude/commands/campfire-complete-slice.md"
expect_file "$TEMP_WORKSPACE/.claude/hooks/campfire-hook-helper.py"
expect_file "$TEMP_WORKSPACE/.claude/hooks/campfire-session-start.sh"
expect_file "$TEMP_WORKSPACE/.claude/hooks/campfire-pre-tool.sh"
expect_file "$TEMP_WORKSPACE/.claude/hooks/campfire-post-tool.sh"
expect_file "$TEMP_WORKSPACE/.claude/hooks/campfire-statusline.sh"
expect_contains "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/checkpoints.json" '"mode": "rolling"'
expect_contains "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/checkpoints.json" '"run_style": "until_stopped"'
expect_contains "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/checkpoints.json" '"guidance"'
expect_contains "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/handoff.md" 'Use $task-framer'
expect_contains /tmp/campfire_example_new.out 'Workspace-specific prompt:'
expect_contains /tmp/campfire_example_new.out 'To switch this task into rolling mode later:'
expect_contains /tmp/campfire_example_roll.out 'Workspace-local follow-ups:'
expect_contains /tmp/campfire_example_prompts.out 'rolling_resume:'
python3 - "$TEMP_WORKSPACE" <<'PY'
import json
import sys
from pathlib import Path

workspace = Path(sys.argv[1]).resolve()
payload = json.loads(Path("/tmp/campfire_example_proposals.json").read_text())
proposals = payload.get("proposals", [])
if [item.get("variant") for item in proposals] != ["rolling_resume", "verifier_sweep", "backlog_refresh"]:
    raise SystemExit("proposal variant mismatch")
names = {item["variant"]: item["name"] for item in proposals}
if names["rolling_resume"] != "Continue verify-example-wrapper-flow":
    raise SystemExit("rolling proposal name mismatch")
if names["verifier_sweep"] != "Sweep verify-example-wrapper-flow verifier":
    raise SystemExit("verifier proposal name mismatch")
if names["backlog_refresh"] != "Refresh verify-example-wrapper-flow backlog":
    raise SystemExit("backlog proposal name mismatch")
for item in proposals:
    normalized_cwds = [str(Path(value).resolve()) for value in item.get("cwds", [])]
    if normalized_cwds != [str(workspace)]:
        raise SystemExit("proposal cwd mismatch")
    if item.get("status") != "ACTIVE":
        raise SystemExit("proposal status mismatch")
    if not str(item.get("prompt", "")).startswith("Use $"):
        raise SystemExit("proposal prompt mismatch")

schedule_payload = json.loads(Path("/tmp/campfire_example_schedule.json").read_text())
scaffolds = schedule_payload.get("scaffolds", [])
if [item.get("variant") for item in scaffolds] != ["rolling_resume", "verifier_sweep", "backlog_refresh"]:
    raise SystemExit("schedule scaffold variant mismatch")
labels = {item["variant"]: item["cadence_label"] for item in scaffolds}
if labels["rolling_resume"] != "Nightly rolling resume":
    raise SystemExit("rolling schedule label mismatch")
if labels["verifier_sweep"] != "Nightly verifier sweep":
    raise SystemExit("verifier schedule label mismatch")
if labels["backlog_refresh"] != "Weekly backlog refresh":
    raise SystemExit("backlog schedule label mismatch")
for item in scaffolds:
    if item.get("platform_scope") != "generic":
        raise SystemExit("schedule platform scope mismatch")
    if item.get("scheduler_binding") != "operator_owned":
        raise SystemExit("schedule scheduler binding mismatch")
    if item.get("local_first") is not True:
        raise SystemExit("schedule local_first mismatch")
    if len(item.get("schedule_examples", [])) < 2:
        raise SystemExit("schedule examples mismatch")
    if len(item.get("operator_questions", [])) < 2:
        raise SystemExit("schedule questions mismatch")
PY
expect_contains /tmp/campfire_example_template.out '.autonomous/'
expect_contains /tmp/campfire_example_guidance.out 'queued next_boundary guidance:'
expect_contains /tmp/campfire_example_template.out 'Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, $task-handoff-state, and $thread-monitor-sidecar'
expect_contains /tmp/campfire_example_template.out './scripts/monitor_task_loop.sh'
expect_contains /tmp/campfire_example_resume.out 'Workspace-specific prompt:'
expect_contains /tmp/campfire_example_resume.out 'Project context:'
expect_contains /tmp/campfire_example_resume.out 'Task context:'
expect_contains /tmp/campfire_example_resume.out 'Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, $task-handoff-state, and $thread-monitor-sidecar'
expect_contains /tmp/campfire_example_resume.out 'Suggested thread monitor sidecar:'
expect_contains /tmp/campfire_example_resume.out "Initial task monitor command: ./scripts/monitor_task_loop.sh $TASK_SLUG"
expect_contains "$TEMP_WORKSPACE/.codex/config.toml" 'codex_hooks = true'
expect_contains "$TEMP_WORKSPACE/.codex/hooks.json" '"SessionStart"'
expect_contains "$TEMP_WORKSPACE/.codex/hooks.json" '"PostToolUse"'
expect_contains "$TEMP_WORKSPACE/.codex/hooks.json" '"UserPromptSubmit"'
expect_contains "$TEMP_WORKSPACE/.codex/hooks.json" '"Stop"'
expect_contains "$TEMP_WORKSPACE/.claude/commands/campfire-resume.md" './scripts/resume_task.sh'
expect_contains "$TEMP_WORKSPACE/.claude/commands/campfire-new-task.md" './scripts/new_task.sh'
expect_contains "$TEMP_WORKSPACE/.claude/commands/campfire-start-slice.md" './scripts/start_slice.sh'
expect_contains "$TEMP_WORKSPACE/.claude/commands/campfire-complete-slice.md" './scripts/complete_slice.sh'

if CLAUDE_PROJECT_DIR="$TEMP_WORKSPACE" "$TEMP_WORKSPACE/.claude/hooks/campfire-pre-tool.sh" <<'EOF' >/tmp/campfire_example_claude_pre_block.out 2>&1
{"tool":"Edit"}
EOF
then
  fail "Claude pre-tool hook should block edits before a slice is active"
else
  PRE_TOOL_STATUS="$?"
fi
[ "$PRE_TOOL_STATUS" -eq 2 ] || fail "Claude pre-tool hook returned unexpected status: $PRE_TOOL_STATUS"
expect_contains /tmp/campfire_example_claude_pre_block.out "./scripts/resume_task.sh $TASK_SLUG"

CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$SKILLS_ROOT/task-handoff-state/scripts/start_slice.sh" --root "$TEMP_WORKSPACE" --from-next --slice-title "Claude adapter verifier slice" "$TASK_SLUG" >/tmp/campfire_example_claude_start_slice.out
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/monitor_task.sh" --json "$TASK_SLUG" >/tmp/campfire_example_monitor.json
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/monitor_task_loop.sh" --interval-seconds 1 "$TASK_SLUG" >/tmp/campfire_example_monitor_loop.out 2>&1 &
MONITOR_LOOP_PID="$!"
sleep 2
kill "$MONITOR_LOOP_PID" >/dev/null 2>&1 || true
wait "$MONITOR_LOOP_PID" >/dev/null 2>&1 || true
MONITOR_LOOP_PID=""
CLAUDE_PROJECT_DIR="$TEMP_WORKSPACE" "$TEMP_WORKSPACE/.claude/hooks/campfire-pre-tool.sh" <<'EOF' >/tmp/campfire_example_claude_pre_allow.out 2>&1
{"tool":"Edit"}
EOF
CLAUDE_PROJECT_DIR="$TEMP_WORKSPACE" CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/.claude/hooks/campfire-post-tool.sh" <<'EOF' >/tmp/campfire_example_claude_post.out 2>&1
{"tool":"Edit"}
EOF

CLAUDE_PROJECT_DIR="$TEMP_WORKSPACE" "$TEMP_WORKSPACE/.claude/hooks/campfire-session-start.sh" <<'EOF' >/tmp/campfire_example_claude_session.out
{"source":"startup"}
EOF
CLAUDE_PROJECT_DIR="$TEMP_WORKSPACE" "$TEMP_WORKSPACE/.claude/hooks/campfire-statusline.sh" <<'EOF' >/tmp/campfire_example_claude_statusline.out
{"session_id":"demo"}
EOF
printf '%s\n' "{\"hook_event_name\":\"SessionStart\",\"source\":\"resume\",\"cwd\":\"$TEMP_WORKSPACE\",\"session_id\":\"demo-session\"}" | CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/.codex/hooks/campfire-session-start.sh" >/tmp/campfire_example_codex_session.out
printf '%s\n' "{\"hook_event_name\":\"PostToolUse\",\"cwd\":\"$TEMP_WORKSPACE\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo ok\"},\"tool_use_id\":\"tool-1\",\"turn_id\":\"demo-turn\",\"session_id\":\"demo-session\"}" | CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/.codex/hooks/campfire-post-tool.sh" >/tmp/campfire_example_codex_post.out
printf '%s\n' "{\"hook_event_name\":\"Stop\",\"cwd\":\"$TEMP_WORKSPACE\",\"stop_hook_active\":false,\"turn_id\":\"demo-turn\",\"session_id\":\"demo-session\"}" | CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/.codex/hooks/campfire-stop.sh" >/tmp/campfire_example_codex_stop.out
expect_contains /tmp/campfire_example_claude_session.out 'Campfire project detected.'
expect_contains /tmp/campfire_example_claude_session.out "task: $TASK_SLUG"
expect_contains /tmp/campfire_example_claude_session.out "./scripts/resume_task.sh $TASK_SLUG"
expect_contains /tmp/campfire_example_claude_statusline.out "campfire $TASK_SLUG"
expect_contains /tmp/campfire_example_codex_session.out '"hookEventName": "SessionStart"'
expect_contains /tmp/campfire_example_codex_session.out "$TASK_SLUG"
expect_contains "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/heartbeat.json" '"source": "codex-post-tool.sh"'
expect_contains /tmp/campfire_example_codex_stop.out '"decision": "block"'
expect_contains /tmp/campfire_example_codex_stop.out "$TASK_SLUG"
CLAUDE_PROJECT_DIR="$TEMP_WORKSPACE" CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/.claude/hooks/campfire-post-tool.sh" <<'EOF' >/tmp/campfire_example_claude_post_again.out 2>&1
{"tool":"Edit"}
EOF
expect_contains "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/heartbeat.json" '"source": "claude-post-tool.sh"'

CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$SKILLS_ROOT/task-handoff-state/scripts/complete_slice.sh" --root "$TEMP_WORKSPACE" --status waiting_on_decision --summary "A real decision boundary is pending." --next-step "Wait for explicit operator input." "$TASK_SLUG" >/dev/null
printf '%s\n' "{\"hook_event_name\":\"UserPromptSubmit\",\"cwd\":\"$TEMP_WORKSPACE\",\"turn_id\":\"demo-turn-2\",\"session_id\":\"demo-session\",\"prompt\":\"continue the task\"}" | CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/.codex/hooks/campfire-user-prompt-submit.sh" >/tmp/campfire_example_codex_prompt.out
expect_contains /tmp/campfire_example_codex_prompt.out '"hookEventName": "UserPromptSubmit"'
expect_contains /tmp/campfire_example_codex_prompt.out 'waiting_on_decision'
expect_contains /tmp/campfire_example_codex_prompt.out 'Do not guess past the unresolved decision boundary'
python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("/tmp/campfire_example_monitor.json").read_text())
if payload.get("recommended_action") != "allow":
    raise SystemExit("example monitor helper should allow the healthy active slice")
if "healthy_active_slice" not in payload.get("reason_codes", []):
    raise SystemExit("example monitor helper reason code mismatch")
PY
expect_file "$TEMP_WORKSPACE/.campfire/monitoring/latest/$TASK_SLUG.json"
expect_file "$TEMP_WORKSPACE/.campfire/monitoring/state/$TASK_SLUG.json"
expect_contains /tmp/campfire_example_monitor_loop.out "monitor_loop: task=$TASK_SLUG"

CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/doctor_task.sh" "$TASK_SLUG" >/tmp/campfire_example_doctor.out
expect_contains /tmp/campfire_example_doctor.out 'Doctor passed:'

CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/record_improvement_candidate.sh" --task-slug "$TASK_SLUG" --candidate-id "example-flow-candidate" --category verifier_candidate --scope repo_local --title "Catch stale state earlier" --problem "Wrapper flow should prove improvement candidates can be stored mechanically." --next-action "Promote the candidate if the wrapper flow stays healthy." >/tmp/campfire_example_candidate.out
expect_file "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/findings/example-flow-candidate.json"
expect_contains "$TEMP_WORKSPACE/.campfire/improvement_backlog.json" 'example-flow-candidate'

CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/record_improvement_candidate.sh" --task-slug "$TASK_SLUG" --candidate-id "example-draft-skill" --category skill_candidate --scope repo_local --title "Draft example wrapper skill" --problem "Example wrappers should prove generated skills can be drafted mechanically." --proposed-skill-name "example-wrapper-skill" --proposed-skill-purpose "Exercise the draft-generated-skill wrapper in the example workspace." --next-action "Review the drafted example skill." >/tmp/campfire_example_skill_candidate.out
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/draft_generated_skill.sh" "example-draft-skill" >/tmp/campfire_example_draft.out
expect_file "$TEMP_WORKSPACE/.campfire/generated-skills/example-wrapper-skill/SKILL.md"
expect_file "$TEMP_WORKSPACE/.campfire/generated-skills/example-wrapper-skill/skill_candidate.json"
expect_file "$TEMP_WORKSPACE/.campfire/skill_inventory.json"
expect_contains /tmp/campfire_example_draft.out 'Drafted generated skill: example-wrapper-skill'

python3 - "$TEMP_WORKSPACE" "$TASK_SLUG" <<'PY'
import json
import sys
from pathlib import Path

workspace = Path(sys.argv[1]).resolve()
task_slug = sys.argv[2]
inventory = json.loads((workspace / ".campfire" / "skill_inventory.json").read_text())
skills = inventory.get("skills", [])
entry = next(item for item in skills if item["skill_name"] == "example-wrapper-skill")
if entry["scope"] != "repo_local_generated":
    raise SystemExit("drafted example skill scope mismatch")

project_context = json.loads((workspace / ".campfire" / "project_context.json").read_text())
repo_skills = project_context.get("discoverable_skills", {}).get("repo_local_generated", [])
if not any(item.get("skill_name") == "example-wrapper-skill" for item in repo_skills):
    raise SystemExit("project context missing drafted example skill")

task_context = json.loads((workspace / ".autonomous" / task_slug / "task_context.json").read_text())
repo_local = task_context.get("skill_surfaces", {}).get("repo_local_generated", [])
if not any(item.get("skill_name") == "example-wrapper-skill" for item in repo_local):
    raise SystemExit("task context missing drafted example skill")
PY

CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/promote_improvement.sh" --task-slug "improve-example-flow-candidate" "example-flow-candidate" >/tmp/campfire_example_promote.out
expect_file "$TEMP_WORKSPACE/.autonomous/improve-example-flow-candidate/plan.md"
expect_contains /tmp/campfire_example_promote.out 'Promoted improvement candidate:'

echo "PASS: Example workspace wrapper verification completed."
