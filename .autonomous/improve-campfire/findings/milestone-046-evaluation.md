# Milestone 046 Evaluation

## Evaluated Milestone

- `milestone-046` - Add an automation proposal helper that emits schedule-agnostic proposal metadata from Campfire state

## Acceptance Criteria

### 1. The helper suggests a stable proposal name and task-only prompt for each supported proposal variant

Pass.

Evidence:

- Added `skills/task-handoff-state/scripts/automation_proposal_helper.sh` and the repo-local wrapper `scripts/automation_proposal_helper.sh`.
- Ran `./skills/task-handoff-state/scripts/automation_proposal_helper.sh improve-campfire` successfully.
- The helper emitted stable proposal names for `rolling_resume`, `verifier_sweep`, and `backlog_refresh`, each paired with a task-only prompt.

### 2. Prompt bodies come from `prompt_template_helper.sh` instead of duplicated inline prose

Pass.

Evidence:

- The helper shells out to `skills/task-handoff-state/scripts/prompt_template_helper.sh` for each proposal variant.
- The rendered proposal prompts matched the existing resume, verifier-sweep, and backlog-refresh template outputs.

### 3. Proposal metadata is derived from the existing task context and local workspace, not a new ad hoc state file

Pass.

Evidence:

- The helper reads `.autonomous/<task>/task_context.json`, `.campfire/project_context.json`, and the existing `checkpoints.json` execution metadata.
- Ran `./scripts/automation_proposal_helper.sh --json improve-campfire` and a Python assertion over the JSON payload to confirm the proposal metadata carries the current milestone, current slice, workspace path, run mode, and run style.

## Result

- `milestone-046` is validated.
- Rolling execution can auto-advance to `milestone-047`.
