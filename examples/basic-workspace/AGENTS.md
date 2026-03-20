# Example Workspace

## Default Workflow

- Create a task with `./scripts/new_task.sh "<objective>"`.
- Resume a task with `./scripts/resume_task.sh <task-slug>`.
- For rolling Codex App runs, switch a task with `./scripts/enable_rolling_mode.sh <task-slug> ...`.
- For rolling Codex App runs, spawn exactly one continuous monitor sidecar with `./scripts/monitor_task_loop.sh <task-slug>` and keep it observer-only between slices.
- Run `./scripts/doctor_task.sh <task-slug>` when you want to confirm the task files and SQL control plane still agree.
- Print rolling automation prompt variants with `./scripts/automation_prompt_helper.sh <task-slug>`.
- Print schedule-agnostic automation proposal metadata with `./scripts/automation_proposal_helper.sh <task-slug>`.
- Print generic automation cadence scaffolds with `./scripts/automation_schedule_scaffold.sh <task-slug>`.
- Use `$long-horizon-worker` with `$task-handoff-state` for long-running multi-step work.
- Use `$task-evaluator` before treating a milestone as fully complete.
- For unattended Codex App runs, prefer a rolling backlog with explicit stop conditions instead of one milestone at a time.
- For recurring Codex App automations, keep prompts task-only and let the automation own schedule plus workspace selection.
- Generate recurring task-only prompts from existing state with `./scripts/automation_prompt_helper.sh <task-slug>` instead of copying examples by hand.
- Use `./scripts/automation_proposal_helper.sh <task-slug>` when you also want a suggested automation name and workspace roots without choosing a schedule yet.
- Use `./scripts/automation_schedule_scaffold.sh <task-slug>` when you want natural-language cadence guidance while keeping scheduler syntax outside Campfire.
- If a named `.autonomous/<task>/` is missing during a continue request, stop and confirm the workspace instead of creating a replacement task.
- If this example lives inside a git repo and you need isolation, prefer worktree-backed bootstrap for risky long runs.
- Keep durable task state under `.autonomous/<task>/`.
- Put project-specific rules here instead of into the global skills.

## Execution Rules

- Keep one stable objective per task slug.
- Work one dependency-safe slice at a time.
- Update `progress.md`, `handoff.md`, `checkpoints.json`, and `artifacts.json` after each meaningful run.
- Let the lifecycle helpers maintain `.campfire/campfire.db`; do not hand-edit the control plane.
- Stop on validation, real blocker, or a user decision boundary.

## Validation Rules

- Prefer explicit commands over vague claims.
- Record review-relevant outputs in `artifacts.json`.
- Record evaluator notes in `findings/` when a milestone gets an explicit completion check.
- Track blockers, retries, and stop reasons in task state.
