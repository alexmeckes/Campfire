# m3 Blocker Journal

## Candidate Blocker

The rolling task can auto-advance milestones mechanically, but queued milestones do not carry their acceptance criteria into `checkpoints.json.current` after `--from-next`.

## Assessment

- This is real workflow friction because an evaluator could otherwise rely on chat memory instead of durable task state.
- It is not a hard blocker for this benchmark run because `plan.md` and the seeded findings already define the forward milestones well enough to restate each current milestone explicitly.
- No external dependency is missing, so marking the task `blocked` here would overstate the risk and distort the benchmark.

## Outcome

- The run stays active.
- Current milestone criteria are restated in durable task state before each evaluation boundary.
- The true hard stop remains the seeded retention-window policy in `m5_decision_stop`.
