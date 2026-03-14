# milestone-021 automation helper backlog

- The new automation-pattern reference is useful, but Campfire still depends on copied prompt text for recurring automations.
- The next leverage point is a helper that reads an existing `.autonomous/<task>/` directory and prints task-only automation prompt variants without mixing in schedule or workspace settings.

## Proposed Backlog

- `milestone-021`: add an automation prompt helper that emits reusable prompt variants from task state
- `milestone-022`: add deterministic verification for automation prompt helper variants and task-state selection
- `milestone-023`: document automation prompt helper usage in README and example guidance

## First Slice

- Add a helper under `skills/task-handoff-state/scripts/` that can print at least `rolling_resume`, `verifier_sweep`, and `backlog_refresh` prompt variants for an existing task slug.
