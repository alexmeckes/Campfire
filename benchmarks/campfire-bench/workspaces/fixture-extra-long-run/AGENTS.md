# Fixture Extra Long Run Workspace

## Purpose

This workspace exists to benchmark Campfire under extra-long neutral workload pressure.

Treat it as a canonical fixture, not as a consumer product repo. The goal is to measure:

- state fidelity over hours
- multiple resume boundaries
- seeded blocker handling
- queue replenish behavior
- decision-boundary correctness

## Default Workflow

- Resume the seeded benchmark task with `./scripts/resume_task.sh fixture-extra-long-run`.
- Use `./scripts/doctor_task.sh fixture-extra-long-run` when you need a control-plane check.
- Use `$task-framer`, `$course-corrector`, `$long-horizon-worker`, `$task-evaluator`, `$task-handoff-state`, and `$task-retrospector` for fresh benchmark threads.
- Treat `benchmark/brief.md`, `benchmark/validation-checklist.md`, `benchmark/inventory.json`, `benchmark/blocker.json`, and `benchmark/decision-boundary.json` as the source-of-truth docs for the benchmark work.

## Execution Rules

- Keep the benchmark objective stable.
- Use the seeded rolling backlog instead of inventing unrelated work.
- Preserve explicit validation evidence as milestones complete.
- Handle the seeded blocker and decision surfaces explicitly; do not bypass them silently.
- Stop explicitly when the benchmark reaches its decision boundary.

## Validation Rules

- Prefer `./scripts/verify_fixture_workspace.sh` as the local workspace check.
- Use the strongest available evidence for each slice:
  1. local file inspection
  2. fixture verifier
  3. `doctor_task.sh`
  4. `resume_task.sh` render
- Record review-relevant outputs in `.autonomous/fixture-extra-long-run/artifacts.json`.
- Record milestone evaluation notes in `.autonomous/fixture-extra-long-run/findings/`.
