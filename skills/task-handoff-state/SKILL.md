---
name: task-handoff-state
description: Use when a project needs standardized durable task state under `.autonomous/<task>/` so Codex can resume work cleanly across sessions. Creates task scaffolding, defines the file contract, and prints resume prompts.
---

# Task Handoff State

Use this skill when a task needs durable on-disk state that survives Codex App restarts, background runs, handoffs, or automations.

This skill standardizes a task directory at `.autonomous/<task>/` inside the active workspace.

Read [references/task-state-contract.md](references/task-state-contract.md) when you need the full file contract and schema conventions.

## What It Creates

Each task directory contains:

- `plan.md`
- `runbook.md`
- `progress.md`
- `handoff.md`
- `checkpoints.json`
- `artifacts.json`
- `logs/`
- `artifacts/`
- `findings/`

Use the bundled scripts to create or inspect that state.

## Quick Start

Create a task in the current workspace:

```bash
~/.codex/skills/task-handoff-state/scripts/init_task.sh "build the next milestone"
```

Create a task in a specific workspace:

```bash
~/.codex/skills/task-handoff-state/scripts/init_task.sh --root /path/to/workspace "build the next milestone"
```

Inspect and resume a task:

```bash
~/.codex/skills/task-handoff-state/scripts/resume_task.sh build-the-next-milestone
```

Switch an existing task into rolling mode:

```bash
~/.codex/skills/task-handoff-state/scripts/enable_rolling_mode.sh build-the-next-milestone --queue "milestone-002:Next slice" --queue "milestone-003:Follow-up slice"
```

Verify the task-state lifecycle:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_task_lifecycle.sh
```

Verify blocked and retry handling:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_blocked_retry.sh
```

Verify course correction handling:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_course_correction.sh
```

Verify task evaluation handling:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_task_evaluation.sh
```

Verify rolling execution handling:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_rolling_execution.sh
```

Verify rolling queue replenishment handling:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_rolling_reframe.sh
```

Verify rolling budget-limit handling:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_budget_limit.sh
```

Verify rolling waiting-on-decision handling:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_waiting_on_decision.sh
```

Verify the rolling-mode helper:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_enable_rolling_mode.sh
```

## File Contract

### `plan.md`

- Stable objective
- source-of-truth docs
- current milestone list
- assumptions or project-specific notes

### `runbook.md`

- setup and boot commands
- validation commands
- observability locations
- required tools, ports, or services

### `progress.md`

- append-only progress log
- what changed
- validation evidence
- blockers
- next slice

### `handoff.md`

- current status
- current milestone
- next slice
- stop reason
- resume prompt for the next Codex run

### `checkpoints.json`

- task slug
- objective
- current status
- phase
- milestone metadata
- execution policy metadata
- blocker metadata
- last run summary and stop reason
- last updated date
- validation evidence list

### `artifacts.json`

- artifact paths
- artifact types
- why each artifact matters
- related milestone or validation

### `findings/`

- evaluation notes
- investigation writeups
- concise reviewer or verifier output that should survive chat history

## Operating Rules

- Keep one stable objective per task slug.
- Do not rename the slug mid-task.
- If the task changes materially, create a new task directory.
- Update `handoff.md` and `checkpoints.json` at the end of every meaningful run.
- Keep `runbook.md` current when setup, validation, or observability changes.
- Record review-relevant outputs in `artifacts.json`.
- Keep logs and generated evidence inside the task folder when practical.
- For unattended Codex App runs, store the rolling execution policy in `checkpoints.json.execution`.
- Dynamic rolling runs should usually enable queue replenishment so a run can keep going until budget, blocker, or decision boundary instead of stopping on an empty queue.

## Pairing

This skill manages state. Pair it with:

- `$long-horizon-worker` for execution discipline
- `$task-evaluator` for explicit milestone completion checks
- project-specific skills for domain rules

## Notes

- If a repo has an `AGENTS.md`, project rules still live there.
- This skill is intentionally generic and should work in any workspace.
