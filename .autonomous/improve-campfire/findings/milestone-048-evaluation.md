# Milestone 048 Evaluation

## Evaluated Milestone

- `milestone-048` - Document automation proposal helper usage in README and example guidance

## Acceptance Criteria

### 1. README and the task-state skill explain when to use proposal metadata versus prompt-only helper output

Pass.

Evidence:

- Updated `README.md` to distinguish prompt-only automation helper usage from schedule-agnostic proposal metadata.
- Updated `skills/task-handoff-state/SKILL.md` to expose the automation proposal helper in the quick-start guidance.

### 2. Example guidance points operators at the local wrapper flow instead of copying prompts by hand

Pass.

Evidence:

- Updated `examples/basic-workspace/AGENTS.md` and `examples/basic-workspace/README.md`.
- The example guidance now points at `./scripts/automation_proposal_helper.sh <task-slug>` as the local wrapper flow.

### 3. The documentation stays schedule-agnostic and local-first

Pass.

Evidence:

- Ran `rg -n "automation_proposal_helper|proposal metadata|prompt-only helper" README.md skills/task-handoff-state/SKILL.md examples/basic-workspace/AGENTS.md examples/basic-workspace/README.md .autonomous/improve-campfire/runbook.md`.
- The updated docs describe names, prompts, and workspace roots without inventing schedule defaults or external automation state.

## Result

- `milestone-048` is validated.
- Rolling execution can auto-advance to `milestone-049`.
