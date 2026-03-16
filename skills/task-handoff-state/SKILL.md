---
name: task-handoff-state
description: Use when a project needs standardized durable task state under `.autonomous/<task>/` so Codex can resume work cleanly across sessions. Creates task scaffolding, defines the file contract, and prints resume prompts.
---

# Task Handoff State

Use this skill when a task needs durable on-disk state that survives Codex App restarts, background runs, handoffs, or automations.

This skill standardizes a task directory at `.autonomous/<task>/` inside the active workspace.

Read [references/task-state-contract.md](references/task-state-contract.md) when you need the full file contract and schema conventions.
Read [references/automation-patterns.md](references/automation-patterns.md) when the task should drive a recurring Codex App automation instead of a one-off run.
Use [scripts/automation_prompt_helper.sh](scripts/automation_prompt_helper.sh) when you want task-only automation prompt variants emitted from existing Campfire state.
Use [scripts/start_slice.sh](scripts/start_slice.sh) to move a task into an active implementation slice before touching project files.
Use [scripts/complete_slice.sh](scripts/complete_slice.sh) to close a slice mechanically and update handoff state, heartbeat, and registry.
Use [scripts/touch_heartbeat.sh](scripts/touch_heartbeat.sh) when you need to refresh task liveness without re-writing the whole handoff.
Use [scripts/refresh_registry.sh](scripts/refresh_registry.sh) to rebuild the repo-local task registry under `.campfire/registry.json`.
Use [scripts/doctor_task.sh](scripts/doctor_task.sh) to compare task files against the SQL control plane and catch drift.

## What It Creates

Each task directory contains:

- `plan.md`
- `runbook.md`
- `progress.md`
- `handoff.md`
- `checkpoints.json`
- `artifacts.json`
- `heartbeat.json`
- `logs/`
- `artifacts/`
- `findings/`

Use the bundled scripts to create or inspect that state.

Campfire now also maintains a lightweight SQLite control plane at `.campfire/campfire.db`. The markdown and JSON files remain compatible operator surfaces, but lifecycle helpers sync them into SQL so widgets, doctors, and future commands can query one transactional source. The same sync pass also renders `.campfire/project_context.json` and `.autonomous/<task>/task_context.json` so resume flows can load structured context before falling back to markdown.

## Quick Start

Create a task in the current workspace:

```bash
~/.codex/skills/task-handoff-state/scripts/init_task.sh "build the next milestone"
```

Bootstrap a task and prefer a git worktree when available:

```bash
~/.codex/skills/task-handoff-state/scripts/bootstrap_task.sh --root /path/to/workspace --worktree "build the next milestone"
```

Create a task in a specific workspace:

```bash
~/.codex/skills/task-handoff-state/scripts/init_task.sh --root /path/to/workspace "build the next milestone"
```

Inspect and resume a task:

```bash
~/.codex/skills/task-handoff-state/scripts/resume_task.sh build-the-next-milestone
```

If `resume_task.sh` reports that the task is missing, treat that as a stop condition for resume/continue requests. Confirm the workspace root and task slug before creating anything new.

Switch an existing task into rolling mode:

```bash
~/.codex/skills/task-handoff-state/scripts/enable_rolling_mode.sh build-the-next-milestone --queue "milestone-002:Next slice" --queue "milestone-003:Follow-up slice"
```

Switch an existing task into manual-stop rolling mode:

```bash
~/.codex/skills/task-handoff-state/scripts/enable_rolling_mode.sh --until-stopped build-the-next-milestone --queue "milestone-002:Next slice" --queue "milestone-003:Follow-up slice"
```

Print task-only automation prompt variants for an existing task:

```bash
~/.codex/skills/task-handoff-state/scripts/automation_prompt_helper.sh build-the-next-milestone
```

Activate the next implementation slice before editing project files:

```bash
~/.codex/skills/task-handoff-state/scripts/start_slice.sh --from-next --slice-title "Implement the next safe slice" build-the-next-milestone
```

Complete a slice and park the task cleanly:

```bash
~/.codex/skills/task-handoff-state/scripts/complete_slice.sh --summary "Validated the current milestone." --next-step "Choose the next milestone." build-the-next-milestone
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

Verify worktree-aware bootstrap handling:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_worktree_bootstrap.sh
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

Verify the missing-resume guardrail:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_missing_resume_guardrail.sh
```

Verify deterministic slice activation:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_start_slice.sh
```

Verify deterministic slice completion:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_complete_slice.sh
```

Verify registry refresh:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_registry_refresh.sh
```

Verify SQL control-plane syncing:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_sql_control_plane.sh
```

Verify recurring automation-pattern coverage:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_automation_patterns.sh
```

Verify automation prompt helper coverage:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_automation_prompt_helper.sh
```

Verify the autonomous rolling floor defaults:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_autonomous_floor.sh
```

Verify the until-stopped rolling style:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_until_stopped_mode.sh
```

Verify that `resume_task.sh` surfaces automation prompt guidance for rolling tasks:

```bash
~/.codex/skills/task-handoff-state/scripts/verify_resume_automation_prompt_guidance.sh
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
- last run summary, stop reason, and run events
- last updated date
- validation evidence list

### `artifacts.json`

- artifact paths
- artifact types
- why each artifact matters
- related milestone or validation

### `heartbeat.json`

- current liveness state for the task
- last seen timestamp
- current milestone and slice
- short summary of the active or most recent work
- append-only updates mirrored into `logs/session.log`

### `findings/`

- evaluation notes
- investigation writeups
- concise reviewer or verifier output that should survive chat history

## Operating Rules

- Keep one stable objective per task slug.
- Do not rename the slug mid-task.
- If the task changes materially, create a new task directory.
- Before implementation edits for a new slice, use `start_slice.sh` or an equivalent deterministic update so `checkpoints.json`, `handoff.md`, and `progress.md` reflect the active work.
- Close validated, blocked, or waiting slices with `complete_slice.sh` so `checkpoints.json`, `handoff.md`, `progress.md`, `heartbeat.json`, and `.campfire/registry.json` stay synchronized.
- Update `handoff.md` and `checkpoints.json` at the end of every meaningful run.
- Keep `runbook.md` current when setup, validation, or observability changes.
- Record review-relevant outputs in `artifacts.json`.
- Keep logs and generated evidence inside the task folder when practical.
- Refresh `.campfire/registry.json` whenever task state changes materially so boards and watchdogs can read one repo-local summary file.
- If a user asks to continue or resume a specific `.autonomous/<task>/` and that task directory is missing, stop and report the missing state. Do not silently create or bootstrap a replacement task.
- For unattended Codex App runs, store the rolling execution policy in `checkpoints.json.execution`.
- Use `automation_prompt_helper.sh` when you want task-only automation prompts generated from existing Campfire state instead of copying examples by hand.
- Dynamic rolling runs should usually enable queue replenishment so a run can keep going until budget, blocker, or decision boundary instead of stopping on an empty queue.
- In rolling mode, record `auto_advanced` and `auto_reframed` in `last_run.events` and keep `last_run.stop_reason` for the real terminal pause reason.
- In `run_style: until_stopped`, remove internal budget/cap stop conditions and keep `manual_pause` external-only.
- For autonomous rolling runs, prefer explicit minimum runtime and milestone floors so the worker does not self-pause after a tiny validated batch.
- For git repos, prefer worktree-backed bootstrap only when isolation helps; keep non-git and low-risk tasks on the in-place path.

## Pairing

This skill manages state. Pair it with:

- `$long-horizon-worker` for execution discipline
- `$task-evaluator` for explicit milestone completion checks
- project-specific skills for domain rules

## Notes

- If a repo has an `AGENTS.md`, project rules still live there.
- This skill is intentionally generic and should work in any workspace.
