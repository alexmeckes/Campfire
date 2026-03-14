# milestone-024 automation helper backlog

- With the stronger autonomous floor in place, Campfire can return to the deferred automation-helper work without immediately pausing after one or two tiny milestones.

## Proposed Backlog

- `milestone-024`: add an automation prompt helper that emits task-only recurring prompt variants from Campfire state
- `milestone-025`: add deterministic verification for automation prompt helper variants and task-state selection
- `milestone-026`: document automation prompt helper usage in README and example guidance
- `milestone-027`: expose automation prompt helper guidance from `resume_task.sh` for rolling tasks
- `milestone-028`: add deterministic verification that `resume_task.sh` surfaces automation-helper guidance correctly

## First Slice

- Add a helper under `skills/task-handoff-state/scripts/` that can print at least `rolling_resume`, `verifier_sweep`, and `backlog_refresh` prompt variants for an existing task slug without mixing schedule or workspace into the prompt body.
