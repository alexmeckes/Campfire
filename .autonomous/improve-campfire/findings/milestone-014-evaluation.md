# milestone-014 evaluation

- Result: validated

## Acceptance criteria

1. Rolling execution policy supports bounded queue replenishment.
   - Evidence: `skills/task-handoff-state/references/task-state-contract.md`
   - Evidence: `skills/long-horizon-worker/SKILL.md`
   - Evidence: `skills/task-handoff-state/scripts/enable_rolling_mode.sh`

2. Campfire proves queue replenishment with deterministic verification coverage.
   - Evidence: `skills/task-handoff-state/scripts/verify_rolling_reframe.sh`
   - Evidence: `./skills/task-handoff-state/scripts/verify_rolling_reframe.sh`

3. README, quick-start text, and example task state describe the dynamic rolling behavior.
   - Evidence: `README.md`
   - Evidence: `examples/basic-workspace/.autonomous/rolling-task/checkpoints.json`
   - Evidence: `examples/basic-workspace/.autonomous/rolling-task/handoff.md`

## Validation summary

- `./skills/task-handoff-state/scripts/verify_rolling_reframe.sh` passed.
- `./scripts/verify_repo.sh` passed with the rolling reframe verifier included.
