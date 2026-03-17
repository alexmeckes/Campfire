Activate a Campfire slice before editing files.

1. Identify the current task from `$ARGUMENTS` or the current Campfire state.
2. Inspect the current milestone and choose the next safe slice.
3. Run `./scripts/start_slice.sh ...` with a concrete slice title before implementation.
4. Only continue after task state moves to `in_progress`.

Rules:

- Do not invent a new milestone if the queue already contains the next safe milestone.
- Keep the slice narrow and validation-oriented.
- If the task is `waiting_on_decision`, stop instead of starting a new slice.
