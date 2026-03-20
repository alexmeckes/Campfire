#!/bin/zsh
set -euo pipefail

EXAMPLE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$HOME/.codex/skills}"
NEW_TASK_SCRIPT="$EXAMPLE_ROOT/scripts/new_task.sh"
RESUME_TASK_SCRIPT="$EXAMPLE_ROOT/scripts/resume_task.sh"
ENABLE_ROLLING_SCRIPT="$EXAMPLE_ROOT/scripts/enable_rolling_mode.sh"
AUTOMATION_PROMPTS_SCRIPT="$EXAMPLE_ROOT/scripts/automation_prompt_helper.sh"
AUTOMATION_PROPOSAL_SCRIPT="$EXAMPLE_ROOT/scripts/automation_proposal_helper.sh"
PROMPT_TEMPLATE_SCRIPT="$EXAMPLE_ROOT/scripts/prompt_template_helper.sh"
QUEUE_GUIDANCE_SCRIPT="$EXAMPLE_ROOT/scripts/queue_guidance.sh"
DOCTOR_TASK_SCRIPT="$EXAMPLE_ROOT/scripts/doctor_task.sh"
RECORD_IMPROVEMENT_SCRIPT="$EXAMPLE_ROOT/scripts/record_improvement_candidate.sh"
PROMOTE_IMPROVEMENT_SCRIPT="$EXAMPLE_ROOT/scripts/promote_improvement.sh"
DRAFT_SKILL_SCRIPT="$EXAMPLE_ROOT/scripts/draft_generated_skill.sh"
MONITOR_TASK_SCRIPT="$EXAMPLE_ROOT/scripts/monitor_task.sh"
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
zsh -n "$NEW_TASK_SCRIPT" "$RESUME_TASK_SCRIPT" "$ENABLE_ROLLING_SCRIPT" "$AUTOMATION_PROMPTS_SCRIPT" "$AUTOMATION_PROPOSAL_SCRIPT" "$PROMPT_TEMPLATE_SCRIPT" "$QUEUE_GUIDANCE_SCRIPT" "$DOCTOR_TASK_SCRIPT" "$RECORD_IMPROVEMENT_SCRIPT" "$PROMOTE_IMPROVEMENT_SCRIPT" "$DRAFT_SKILL_SCRIPT" "$MONITOR_TASK_SCRIPT" "$CLAUDE_SESSION_START_HOOK" "$CLAUDE_PRE_TOOL_HOOK" "$CLAUDE_POST_TOOL_HOOK" "$CLAUDE_STATUSLINE_HOOK" "$EXAMPLE_ROOT/scripts/verify_harness.sh"
python3 -m py_compile "$CLAUDE_HOOK_HELPER"

echo "== Skill presence =="
expect_file "$SKILLS_ROOT/task-handoff-state/SKILL.md"
expect_file "$SKILLS_ROOT/task-framer/SKILL.md"
expect_file "$SKILLS_ROOT/long-horizon-worker/SKILL.md"
expect_file "$SKILLS_ROOT/task-evaluator/SKILL.md"
expect_file "$SKILLS_ROOT/course-corrector/SKILL.md"

echo "== Temp workspace wrapper flow =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_example_new.out /tmp/campfire_example_roll.out /tmp/campfire_example_prompts.out /tmp/campfire_example_proposals.json /tmp/campfire_example_template.out /tmp/campfire_example_guidance.out /tmp/campfire_example_resume.out /tmp/campfire_example_monitor.json' EXIT
mkdir -p "$TEMP_WORKSPACE/scripts"
cp "$NEW_TASK_SCRIPT" "$RESUME_TASK_SCRIPT" "$ENABLE_ROLLING_SCRIPT" "$AUTOMATION_PROMPTS_SCRIPT" "$AUTOMATION_PROPOSAL_SCRIPT" "$PROMPT_TEMPLATE_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp "$QUEUE_GUIDANCE_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp "$DOCTOR_TASK_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp "$RECORD_IMPROVEMENT_SCRIPT" "$PROMOTE_IMPROVEMENT_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp "$DRAFT_SKILL_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp "$MONITOR_TASK_SCRIPT" "$TEMP_WORKSPACE/scripts/"
cp -R "$EXAMPLE_ROOT/.claude" "$TEMP_WORKSPACE/"
chmod +x "$TEMP_WORKSPACE"/scripts/*.sh
chmod +x "$TEMP_WORKSPACE/.claude/hooks/"*.sh

CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/new_task.sh" --slug "$TASK_SLUG" "verify example wrapper flow" >/tmp/campfire_example_new.out
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/enable_rolling_mode.sh" --until-stopped --queue "milestone-002:Next slice" --queue "milestone-003:Follow-up slice" "$TASK_SLUG" >/tmp/campfire_example_roll.out
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/automation_prompt_helper.sh" "$TASK_SLUG" >/tmp/campfire_example_prompts.out
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$TEMP_WORKSPACE/scripts/automation_proposal_helper.sh" --json "$TASK_SLUG" >/tmp/campfire_example_proposals.json
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
    if item.get("cwds") != [str(workspace)]:
        raise SystemExit("proposal cwd mismatch")
    if item.get("status") != "ACTIVE":
        raise SystemExit("proposal status mismatch")
    if not str(item.get("prompt", "")).startswith("Use $"):
        raise SystemExit("proposal prompt mismatch")
PY
expect_contains /tmp/campfire_example_template.out '.autonomous/'
expect_contains /tmp/campfire_example_guidance.out 'queued next_boundary guidance:'
expect_contains /tmp/campfire_example_template.out 'Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state'
expect_contains /tmp/campfire_example_resume.out 'Workspace-specific prompt:'
expect_contains /tmp/campfire_example_resume.out 'Project context:'
expect_contains /tmp/campfire_example_resume.out 'Task context:'
expect_contains /tmp/campfire_example_resume.out 'Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state'
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
expect_contains /tmp/campfire_example_claude_session.out 'Campfire project detected.'
expect_contains /tmp/campfire_example_claude_session.out "task: $TASK_SLUG"
expect_contains /tmp/campfire_example_claude_session.out "./scripts/resume_task.sh $TASK_SLUG"
expect_contains /tmp/campfire_example_claude_statusline.out "campfire $TASK_SLUG"
expect_contains "$TEMP_WORKSPACE/.autonomous/$TASK_SLUG/heartbeat.json" '"source": "claude-post-tool.sh"'
python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path("/tmp/campfire_example_monitor.json").read_text())
if payload.get("recommended_action") != "allow":
    raise SystemExit("example monitor helper should allow the healthy active slice")
if "healthy_active_slice" not in payload.get("reason_codes", []):
    raise SystemExit("example monitor helper reason code mismatch")
PY

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
