# Example Workspace

## Default Workflow

- Use `$long-horizon-worker` with `$task-handoff-state` for long-running multi-step work.
- Keep durable task state under `.autonomous/<task>/`.
- Put project-specific rules here instead of into the global skills.

## Execution Rules

- Keep one stable objective per task slug.
- Work one dependency-safe slice at a time.
- Update `progress.md`, `handoff.md`, `checkpoints.json`, and `artifacts.json` after each meaningful run.
- Stop on validation, real blocker, or a user decision boundary.

## Validation Rules

- Prefer explicit commands over vague claims.
- Record review-relevant outputs in `artifacts.json`.
- Track blockers, retries, and stop reasons in task state.
