# Milestone 041 Steering Versus Follow-Up Queue

## Goal

Add a lightweight operator-guidance model that distinguishes between:

- guidance that should interrupt the worker immediately
- guidance that should wait until the next safe milestone or slice boundary

## Acceptance Focus

- Campfire can persist guidance entries with a clear intent such as `interrupt_now` or `next_boundary`.
- The task-state contract and generated context surfaces expose both the active interrupting guidance and any queued follow-up guidance.
- The model stays single-agent and local-first: it is a small queue and visibility surface, not a scheduler or multi-agent router.

## Next Slice

- Add a small `guidance_entries` surface to the SQL control plane and task projections.
- Reflect the same distinction in `checkpoints.json`, `task_context.json`, and `.campfire/registry.json`.
- Add deterministic coverage for interrupt-now versus follow-up visibility without inventing new orchestration roles.

## Validation Target

- targeted control-plane sync checks in `campfire_sql.py`
- a deterministic verifier for steering versus follow-up visibility
- `./scripts/verify_repo.sh`
