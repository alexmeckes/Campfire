# Runbook

## Workspace

- Root: /Users/alexmeckes/Downloads/Campfire/benchmarks/campfire-bench/workspaces/fixture-long-run
- Task: fixture-long-run

## Boot / Setup

- No external services required.
- Use local wrappers under `scripts/`.
- Set `CAMPFIRE_SKILLS_ROOT=/Users/alexmeckes/Downloads/Campfire/skills` when verifying inside the Campfire repo.

## Validation

- Primary:
  - `./scripts/verify_fixture_workspace.sh`
- Secondary:
  - `./scripts/doctor_task.sh fixture-long-run`
  - `./scripts/resume_task.sh fixture-long-run`
- Review benchmark files:
  - `benchmark/inventory.json`
  - `benchmark/validation-checklist.md`
  - `benchmark/reports/`

## Observability

- Logs: `.autonomous/fixture-long-run/logs/`
- Artifacts: `.autonomous/fixture-long-run/artifacts/`
- Findings: `.autonomous/fixture-long-run/findings/`

## Notes

- This workspace is intentionally domain-neutral.
- Treat report and artifact files as benchmark evidence, not as product deliverables.
