# m4 Queue Refresh

## Goal

Replenish the rolling queue in a bounded way after the active backlog dropped below the configured target depth, without inventing unrelated work or bypassing the seeded gates.

## Reframe Inputs

- Before `m4`, the remaining queued milestones were `m5_blocker_gate`, `m6_recovery_report`, and `m7_decision_stop`.
- The execution policy targets a queue depth of `4`, so a bounded planning pass was allowed.
- The benchmark brief still requires the run to stop on the pending `m7` decision boundary.

## Replenish Action

- Added one conditional follow-up milestone to `execution.queued_milestones`:
  - `m8_post_decision_follow_through` - Apply the archive-versus-preserve decision after explicit operator input
- Kept the new milestone behind the `m7` operator decision instead of assuming through it.
- Updated `plan.md` to record that `m8` is a neutral replenishment artifact, not a new seeded benchmark objective.

## Validation Evidence

- `.autonomous/fixture-extra-long-run/artifacts/m4-resume.txt`
  - Resume render shows the replenished queue as `m5`, `m6`, `m7`, and `m8`.
- `.autonomous/fixture-extra-long-run/artifacts/m4-doctor.txt`
  - Doctor still passes while the queue is refreshed.
- `.autonomous/fixture-extra-long-run/artifacts/m4-verify-fixture.txt`
  - Fixture verifier still passes, so the reframe did not corrupt the seeded benchmark surfaces.

## Conclusion

Queue replenishment occurred once, stayed neutral and benchmark-scoped, and preserved the blocker and decision boundary as real future gates.
