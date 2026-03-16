# Milestone 041 Evaluation

## Evaluated Milestone

- `milestone-041` - Add a lightweight steering versus follow-up queue model for active tasks

## Acceptance Criteria

### 1. Campfire can persist operator guidance with a clear mode such as `interrupt_now` or `next_boundary`

Pass.

Evidence:

- Added `skills/task-handoff-state/scripts/queue_guidance.sh` plus repo/example wrappers.
- Added `guidance_entries` persistence and guidance normalization in `skills/task-handoff-state/scripts/campfire_sql.py`.
- Ran `./skills/task-handoff-state/scripts/verify_guidance_queue.sh` successfully, which proves both `interrupt_now` and `next_boundary` entries persist through `checkpoints.json`, SQLite, `task_context.json`, and `.campfire/registry.json`.

### 2. The state contract and generated context surfaces expose active steering versus queued follow-up guidance clearly

Pass.

Evidence:

- Updated `skills/task-handoff-state/references/task-state-contract.md`, `skills/task-handoff-state/SKILL.md`, `docs/campfire-v3-control-plane.md`, and `README.md` to document the guidance surface.
- Updated `campfire_sql.py` so generated task context exposes the active guidance entry plus follow-ups and registry entries expose active/follow-up counts plus the active summary.
- Ran `./scripts/verify_repo.sh` successfully after wiring the new verifier and wrapper coverage.

### 3. The model stays single-agent and local-first instead of becoming a scheduler or multi-agent routing layer

Pass.

Evidence:

- The persisted model is one active entry plus ordered follow-ups scoped to a single task.
- The helper only mutates task-local state and re-renders projections; it does not schedule work, branch agents, or add routing semantics.
- The control-plane doc now states that `guidance_entries` must not become a scheduler or multi-agent surface.

## Result

- `milestone-041` is validated.
- Rolling execution can auto-advance to `milestone-042`.
