# m1 State Baseline

## Scope

Confirm that the canonical extra-long fixture can be resumed from workspace state alone and that the seeded benchmark surfaces agree on the intended run shape.

## Source Alignment

- `benchmark/brief.md` defines the seeded milestone order as `m1` through `m7`.
- `benchmark/inventory.json` maps the same seven phases to report artifacts under `benchmark/reports/`.
- `benchmark/blocker.json` leaves the blocker pending until `m5_blocker_gate` and requires an explicit recorded blocker state before continuing.
- `benchmark/decision-boundary.json` leaves the archive-versus-preserve question pending and forbids assumption through the stop.

## Validation Evidence

- `CAMPFIRE_SKILLS_ROOT=/Users/alexmeckes/Downloads/Campfire/skills ./scripts/verify_fixture_workspace.sh`
  - Output captured in `.autonomous/fixture-extra-long-run/artifacts/m1-verify-fixture.txt`
  - Result: `PASS: Fixture extra-long workspace verification completed.`
- `./scripts/doctor_task.sh fixture-extra-long-run`
  - Output captured in `.autonomous/fixture-extra-long-run/artifacts/m1-doctor.txt`
  - Result: control-plane check passed with task status `in_progress` and heartbeat `active`.
- `./scripts/resume_task.sh fixture-extra-long-run`
  - Output captured in `.autonomous/fixture-extra-long-run/artifacts/m1-resume.txt`
  - Result: resume render enumerated the benchmark source docs, the queued milestones `m2` through `m7`, the rolling execution policy, and the workspace-specific prompt without any dependency on prior chat state.

## Conclusion

The baseline fixture state is coherent. The seeded blocker and decision-boundary surfaces are present, still pending, and visible from the local resume surface, so the run can proceed into the queued benchmark backlog without changing the benchmark objective.
