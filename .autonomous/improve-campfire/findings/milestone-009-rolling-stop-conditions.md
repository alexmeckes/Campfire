# milestone-009 rolling stop conditions

Campfire already verifies rolling auto-advance on success, but it does not yet prove the two other common Codex App stop modes:

1. the run hits its budget with queued work still remaining
2. the run reaches a real decision boundary and must pause cleanly

The next rolling backlog should cover those states explicitly.

## Proposed backlog

1. `milestone-009` - add deterministic rolling budget-limit verification coverage
2. `milestone-010` - add deterministic rolling waiting-on-decision verification coverage
3. `milestone-011` - document rolling stop-condition behavior in the README, verifier list, and example guidance

## Acceptance criteria

- `verify_budget_limit.sh` proves a rolling task can stop on `budget_limit` while preserving queued milestones and a concrete resume target
- `verify_waiting_on_decision.sh` proves a rolling task can stop on `waiting_on_decision` with the unresolved decision recorded in task state
- `verify_repo.sh`, `README.md`, and the task-state docs all expose the new stop-condition coverage
