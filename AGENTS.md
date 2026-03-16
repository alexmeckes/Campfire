# Campfire Repo Workflow

## Default Workflow

- Use `$task-framer` when a task is not yet concrete.
- Use `$long-horizon-worker` with `$task-handoff-state` for multi-step execution.
- Use `$course-corrector` when new facts or blockers change the best path.
- Use `$task-evaluator` when a milestone seems done or needs an independent completion check.
- Use `$task-retrospector` after meaningful completed, failed, or benchmarked runs to turn lessons into benchmark, verifier, skill, or control-plane improvements.
- Treat generated skills conservatively: create candidates first, keep drafts task-local or repo-local by default, and only promote to Campfire core with benchmark-backed evidence.
- For Codex App runs that should keep going while the user is away, use rolling execution in `checkpoints.json` with queued milestones and bounded planning slices.
- Keep durable task state under `.autonomous/<task>/`.
- Create a task with `./scripts/new_task.sh "<objective>"`.
- Resume a task with `./scripts/resume_task.sh <task-slug>`.
- Start a new implementation slice with `./scripts/start_slice.sh ...` before touching project files.
- Close a slice with `./scripts/complete_slice.sh ...` so status, heartbeat, and registry stay synchronized.
- Run `./scripts/doctor_task.sh <task-slug>` when you need a quick consistency check between task files and the SQL control plane.

## Repo Scope

- Keep Campfire generic. Project-specific rules belong in the target project, not in the global skills.
- Prefer improving the reusable skill contract, scripts, verifiers, installer, and examples over repo-specific convenience layers.
- If a change adds complexity, it should improve portability, verification, or long-horizon reliability.

## Validation Rules

- Update task state as you go: `progress.md`, `handoff.md`, `checkpoints.json`, and `artifacts.json`.
- Keep heartbeat and registry current through the lifecycle helpers instead of hand-editing them.
- Treat `.campfire/campfire.db` as the runtime control plane. Markdown and JSON files are operator-facing projections and compatibility outputs.
- Prefer explicit shell-based verification over vague claims.
- Keep verifier scripts deterministic and workspace-local when practical.

## Priorities

- Strong state contract
- Clear resume and handoff semantics
- Verifiers for success, failure, retry, and evaluation paths
- Minimal instructions with durable scripts
