# Prompt Templates

Campfire keeps a small prompt-template layer for canonical operator flows so the common resume and follow-up prompts do not drift across scripts, docs, and example workspaces.

Use the shared helper:

```bash
~/.codex/skills/task-handoff-state/scripts/prompt_template_helper.sh <template-name>
```

Task-scoped templates require `--task-slug <task-slug>`.

## Available Templates

- `task_bootstrap`
  - For a freshly created task that still needs framing before the first implementation slice.
- `resume`
  - Resolves from task state and prints the right single-milestone, bounded rolling, or `until_stopped` resume prompt.
  - For rolling Codex runs, the rendered prompt includes the monitor-sidecar instruction and the repo-local `./scripts/monitor_task_loop.sh <task-slug>` command.
- `rolling_resume`
  - Alias for `resume` when the caller wants automation-oriented naming.
- `verifier_sweep`
  - Prints the canonical evaluator prompt for re-running the strongest listed validation against a task.
- `backlog_refresh`
  - Prints the canonical framing and course-correction prompt for replenishing the next queued milestones.
- `retrospective`
  - Prints the canonical retrospection prompt for extracting reusable lessons from an existing task.
- `benchmark`
  - Prints the canonical benchmark-review prompt for `benchmarks/campfire-bench/`.
- `improvement_promotion`
  - Prints the canonical prompt for continuing a newly promoted improvement task. Pass `--task-slug` and optionally `--candidate-id`.

## Examples

Resume a rolling task:

```bash
~/.codex/skills/task-handoff-state/scripts/prompt_template_helper.sh --task-slug improve-campfire resume
```

Generate the retrospective prompt for a task:

```bash
~/.codex/skills/task-handoff-state/scripts/prompt_template_helper.sh --task-slug improve-campfire retrospective
```

Generate the benchmark prompt:

```bash
~/.codex/skills/task-handoff-state/scripts/prompt_template_helper.sh benchmark
```

Generate the promoted-improvement prompt:

```bash
~/.codex/skills/task-handoff-state/scripts/prompt_template_helper.sh --task-slug improve-slice-start --candidate-id slice-start-guard improvement_promotion
```
