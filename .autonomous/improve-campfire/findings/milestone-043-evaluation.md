# Milestone 043 Evaluation

## Evaluated Milestone

- `milestone-043` - Add session-lineage metadata for retries, branches, and benchmark repros

## Acceptance Criteria

### 1. Task sessions can record stable run identifiers plus parent-child lineage for retries or course-corrected runs

Pass.

Evidence:

- Extended `skills/task-handoff-state/scripts/start_slice.sh` to emit stable `run_id` values plus optional `parent_run_id`, `lineage_kind`, and `branch_label` metadata.
- Extended `skills/task-handoff-state/scripts/campfire_sql.py` so sessions persist run identifiers and lineage metadata in the SQL control plane and generated projections.
- Ran `./skills/task-handoff-state/scripts/verify_session_lineage.sh` successfully, which proves base, retry, and benchmark-repro branches all persist in session history.

### 2. Benchmark or retrospective evidence can point at specific run branches through the same run identifier surface

Pass.

Evidence:

- `record_improvement_candidate.sh` already accepts `--source-run-id`, and the lineage verifier now records evidence against a benchmark-style run branch.
- Updated generated task and registry context so the latest `run_id` and lineage metadata remain queryable after refresh.
- Updated `docs/campfire-bench.md` and the task-state/control-plane docs to tie benchmark `run_id` values back to task-session lineage.

### 3. The implementation stays local and queryable inside the existing SQL control plane and generated context

Pass.

Evidence:

- Added session columns in the existing SQLite control plane instead of introducing a separate lineage service or branch database.
- `doctor_task.sh`, `task_context.json`, and `.campfire/registry.json` all validate or expose the same lineage metadata.
- Ran `./scripts/verify_repo.sh` successfully after wiring the session-lineage verifier and the higher-precision session timestamps.

## Result

- `milestone-043` is validated.
- The Pi-inspired backlog is complete, so rolling execution should spend one bounded reframe replenishing the queue before it stops.
