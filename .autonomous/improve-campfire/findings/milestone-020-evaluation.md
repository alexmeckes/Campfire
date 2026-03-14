# milestone-020 evaluation

## Scope

Evaluated the recurring automation backlog covering milestones 018 through 020.

## Result

- Milestone-018 passed: Campfire now has a reusable automation-pattern reference at `skills/task-handoff-state/references/automation-patterns.md`, and the generic task-state skill points to it.
- Milestone-019 passed: deterministic coverage exists through `skills/task-handoff-state/scripts/verify_automation_patterns.sh`, and the example rolling task now carries an automation-ready note.
- Milestone-020 passed: `README.md`, `examples/basic-workspace/AGENTS.md`, and the rolling example guidance now explain when to use recurring automations versus one-off rolling runs.

## Strongest Evidence

- `./skills/task-handoff-state/scripts/verify_automation_patterns.sh`
- `./scripts/verify_repo.sh`

## Next Step

Reframe the next backlog around an automation prompt helper so recurring runs can emit task-only prompts from existing Campfire state instead of relying on copied examples.
