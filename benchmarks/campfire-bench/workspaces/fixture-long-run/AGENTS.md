# Fixture Long Run Workspace

## Purpose

This workspace exists to benchmark Campfire itself.

Treat it as a neutral long-horizon fixture, not as a product repo. The goal is to measure:

- state fidelity
- resume fidelity
- queue replenish behavior
- validation quality
- stop correctness

## Default Workflow

- Resume the seeded benchmark task with `./scripts/resume_task.sh fixture-long-run`.
- Use `./scripts/doctor_task.sh fixture-long-run` before and after a long run when you need a control-plane check.
- Use `$task-framer`, `$course-corrector`, `$long-horizon-worker`, `$task-evaluator`, `$task-handoff-state`, and `$task-retrospector` for fresh benchmark threads.
- Use the local wrapper scripts instead of calling installed skills directly when possible.
- Treat `benchmark/brief.md`, `benchmark/validation-checklist.md`, and `benchmark/inventory.json` as the source-of-truth docs for benchmark work.

## Execution Rules

- Keep the benchmark objective stable.
- Work one dependency-safe slice at a time.
- Use the seeded rolling backlog instead of inventing unrelated work.
- Prefer queue replenish and bounded reframe when the current queue runs thin.
- Stop explicitly on a real decision boundary instead of guessing through it.
- Do not convert this workspace into a product or demo project.

## Validation Rules

- Prefer `./scripts/verify_fixture_workspace.sh` as the local workspace check.
- Use the strongest available evidence for each slice:
  1. local file inspection
  2. fixture verifier
  3. `doctor_task.sh`
  4. `resume_task.sh` render
- Record review-relevant outputs in `.autonomous/fixture-long-run/artifacts.json`.
- Record milestone evaluation notes in `.autonomous/fixture-long-run/findings/`.
