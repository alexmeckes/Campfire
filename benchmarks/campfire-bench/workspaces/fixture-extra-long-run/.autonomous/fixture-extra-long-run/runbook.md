# Runbook

## Workspace

- Root: /Users/alexmeckes/Downloads/Campfire/benchmarks/campfire-bench/workspaces/fixture-extra-long-run
- Task: fixture-extra-long-run

## Boot / Setup

- No external services required.
- Use local wrappers under `scripts/`.
- Set `CAMPFIRE_SKILLS_ROOT=/Users/alexmeckes/Downloads/Campfire/skills` when verifying inside the Campfire repo.

## Validation

- Primary:
  - `./scripts/verify_fixture_workspace.sh`
- Secondary:
  - `./scripts/doctor_task.sh fixture-extra-long-run`
  - `./scripts/resume_task.sh fixture-extra-long-run`
- Review benchmark files:
  - `benchmark/inventory.json`
  - `benchmark/blocker.json`
  - `benchmark/decision-boundary.json`
  - `benchmark/reports/`

## Observability

- Logs: `.autonomous/fixture-extra-long-run/logs/`
- Artifacts: `.autonomous/fixture-extra-long-run/artifacts/`
- Findings: `.autonomous/fixture-extra-long-run/findings/`

## Notes

- This workspace is intentionally domain-neutral.
- Treat blocker and decision files as benchmark signals, not as product requirements.
