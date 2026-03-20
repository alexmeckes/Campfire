# m5 Decision Note

## Decision Boundary

- Policy id: `retention-window-policy`
- Question: should the fixture retain every generated report, or trim report history after each completed long-run cycle?
- Current status: unresolved

## Why The Run Stops Here

- The choice changes how benchmark evidence is kept between long-run cycles, so neither branch is safe to assume silently.
- The m4 replenish added only decision-dependent follow-ups:
  - `m6_retention_policy_apply`
  - `m7_post_decision_verification`
- Auto-starting either follow-up without the policy answer would defeat the point of the benchmark stop surface.

## Expected Task-State Outcome

- `status`: `waiting_on_decision`
- `stop_reason`: `waiting_on_decision`
- queued follow-ups remain visible from resume output but must not start automatically
