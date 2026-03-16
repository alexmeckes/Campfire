# Milestone 049 Evaluation

## Evaluated Milestone

- `milestone-049` - Surface automation proposal guidance from `resume_task.sh` for rolling tasks

## Acceptance Criteria

### 1. Rolling resume output exposes the proposal helper as an optional next step next to the prompt-only variants

Pass.

Evidence:

- Updated `skills/task-handoff-state/scripts/resume_task.sh` to print `Automation proposal metadata:` for rolling tasks.
- Ran `./scripts/resume_task.sh improve-campfire` and confirmed the proposal section appears immediately after the prompt-only automation variants.

### 2. Resume output stays compatible with existing rolling guidance and does not invent schedule defaults

Pass.

Evidence:

- The resume output still prints the existing `Automation prompt variants:` block unchanged.
- The new proposal block only includes names, prompts, workspace roots, status, and current task metadata; it does not emit schedules or external automation state.

### 3. The new guidance reuses the proposal helper instead of duplicating its output logic

Pass.

Evidence:

- `skills/task-handoff-state/scripts/resume_task.sh` shells out to `automation_proposal_helper.sh` instead of formatting proposal metadata inline.
- The surfaced proposal text matches the direct helper output for the current task.

## Result

- `milestone-049` is validated.
- Rolling execution can auto-advance to `milestone-050`.
