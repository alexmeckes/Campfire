# milestone-011 evaluation

- Result: validated

## Acceptance criteria

1. Campfire includes deterministic `budget_limit` and `waiting_on_decision` rolling verifiers.
   - Evidence: `skills/task-handoff-state/scripts/verify_budget_limit.sh`
   - Evidence: `skills/task-handoff-state/scripts/verify_waiting_on_decision.sh`

2. The repo verification suite runs both new stop-condition verifiers.
   - Evidence: `scripts/verify_repo.sh`
   - Evidence: `./scripts/verify_repo.sh`

3. README and task-state docs explain that rolling pauses preserve the active milestone and queued backlog.
   - Evidence: `README.md`
   - Evidence: `skills/task-handoff-state/SKILL.md`
   - Evidence: `skills/task-handoff-state/references/task-state-contract.md`

## Validation summary

- `./skills/task-handoff-state/scripts/verify_budget_limit.sh` passed.
- `./skills/task-handoff-state/scripts/verify_waiting_on_decision.sh` passed.
- `./scripts/verify_repo.sh` passed with both new stop-condition verifiers included.
