# Campfire Repo Workflow

## Default Workflow

- Use `$task-framer` when a task is not yet concrete.
- Use `$long-horizon-worker` with `$task-handoff-state` for multi-step execution.
- Use `$course-corrector` when new facts or blockers change the best path.
- Use `$task-evaluator` when a milestone seems done or needs an independent completion check.
- Keep durable task state under `.autonomous/<task>/`.
- Create a task with `./scripts/new_task.sh "<objective>"`.
- Resume a task with `./scripts/resume_task.sh <task-slug>`.

## Repo Scope

- Keep Campfire generic. Project-specific rules belong in the target project, not in the global skills.
- Prefer improving the reusable skill contract, scripts, verifiers, installer, and examples over repo-specific convenience layers.
- If a change adds complexity, it should improve portability, verification, or long-horizon reliability.

## Validation Rules

- Update task state as you go: `progress.md`, `handoff.md`, `checkpoints.json`, and `artifacts.json`.
- Prefer explicit shell-based verification over vague claims.
- Keep verifier scripts deterministic and workspace-local when practical.

## Priorities

- Strong state contract
- Clear resume and handoff semantics
- Verifiers for success, failure, retry, and evaluation paths
- Minimal instructions with durable scripts
