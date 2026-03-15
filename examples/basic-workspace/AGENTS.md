# Example Workspace

## Default Workflow

- Create a task with `./scripts/new_task.sh "<objective>"`.
- Resume a task with `./scripts/resume_task.sh <task-slug>`.
- For rolling Codex App runs, switch a task with `./scripts/enable_rolling_mode.sh <task-slug> ...`.
- Print rolling automation prompt variants with `./scripts/automation_prompt_helper.sh <task-slug>`.
- Use `$long-horizon-worker` with `$task-handoff-state` for long-running multi-step work.
- Use `$task-evaluator` before treating a milestone as fully complete.
- For unattended Codex App runs, prefer a rolling backlog with explicit stop conditions instead of one milestone at a time.
- For recurring Codex App automations, keep prompts task-only and let the automation own schedule plus workspace selection.
- Generate recurring task-only prompts from existing state with `./scripts/automation_prompt_helper.sh <task-slug>` instead of copying examples by hand.
- If a named `.autonomous/<task>/` is missing during a continue request, stop and confirm the workspace instead of creating a replacement task.
- If this example lives inside a git repo and you need isolation, prefer worktree-backed bootstrap for risky long runs.
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
- Record evaluator notes in `findings/` when a milestone gets an explicit completion check.
- Track blockers, retries, and stop reasons in task state.
