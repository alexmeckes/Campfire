Use the repo-local Campfire wrappers first.

1. If the user provided a task slug in `$ARGUMENTS`, run `./scripts/resume_task.sh $ARGUMENTS`.
2. Otherwise inspect `.campfire/registry.json` and choose the most relevant active or resumable task.
3. Read the emitted project context, task context, checkpoint summary, and workspace-specific prompt.
4. Continue only if the task is not parked on a real decision boundary.

Rules:

- If the task is `waiting_on_decision`, stop and ask for the missing product or operator choice.
- If `resume_task.sh` says the task is missing, do not create a replacement task unless the user explicitly asked for a new task.
- When resuming real implementation work, activate or continue the current slice through Campfire rather than bypassing task state.
