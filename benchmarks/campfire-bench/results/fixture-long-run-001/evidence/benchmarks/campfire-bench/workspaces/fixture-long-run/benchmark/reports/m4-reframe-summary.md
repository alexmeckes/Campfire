# m4 Reframe Summary

## Trigger

At the start of `m4_backlog_refresh`, the rolling queue had reached the configured replenish threshold with only `m5_decision_stop` remaining.

## Reframe Result

- The queue was replenished to stay benchmark-scoped instead of inventing unrelated work.
- Two contingent follow-ups were added after `m5`:
  - `m6_retention_policy_apply`: apply the report-retention policy once an operator makes the decision.
  - `m7_post_decision_verification`: re-run the neutral verifier, doctor, and resume surfaces after that policy is applied.

## Why These Milestones Are Safe

- Both follow-ups are purely about benchmark report handling and validation, not product behavior.
- Both are explicitly decision-dependent, so they do not authorize guessing through `m5`.
- The next active milestone remains `m5_decision_stop`, which preserves the seeded stop boundary.
