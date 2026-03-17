Bootstrap a new Campfire task in this repo.

1. Run `./scripts/new_task.sh "$ARGUMENTS"`.
2. Inspect the created task state and the emitted workspace-specific prompt.
3. If the objective is still vague, use Campfire framing behavior before implementation.

Rules:

- Keep the objective stable.
- Prefer a bounded first slice with explicit validation.
- Do not start editing project files until the first slice is clear.
