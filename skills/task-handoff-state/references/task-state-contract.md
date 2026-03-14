# Task State Contract

This reference defines the durable file contract for `.autonomous/<task>/`.

## Required Files

- `plan.md`
- `runbook.md`
- `progress.md`
- `handoff.md`
- `checkpoints.json`
- `artifacts.json`
- `logs/`
- `artifacts/`
- `findings/`

## Purpose

### `plan.md`

The stable task definition.

- objective
- source-of-truth docs
- milestone checklist
- assumptions and project notes

### `runbook.md`

The environment and verification guide.

- boot or setup commands
- validation commands
- observability locations
- ports, services, or tool requirements
- artifact capture expectations

### `progress.md`

Append-only run history.

- what changed
- what passed or failed
- blockers and retries
- next slice

### `handoff.md`

The concise resume note for the next run.

- current status
- current milestone
- next slice
- stop reason
- resume prompt

### `checkpoints.json`

Machine-readable state for long-horizon runs.

Suggested fields:

- `task_slug`
- `objective`
- `status`
- `phase`
- `current`
- `execution`
- `blocker`
- `workspace`
- `last_run`
- `last_run.events`
- `runbook`
- `artifacts_manifest`
- `validation`
- `last_updated`

### `artifacts.json`

Machine-readable artifact manifest.

- paths to outputs that matter
- type of artifact
- reason it matters
- which milestone or validation it supports

### Optional `workspace` metadata

When bootstrap logic chooses between in-place and git-worktree setup, record that choice in `checkpoints.json.workspace`.

Suggested fields:

- `strategy`: `in_place` or `git_worktree`
- `root`: the active workspace root for the task
- `git_root`: the parent git repo root when a worktree is used
- `branch`: the active branch when worktree-backed setup created one

### `findings/`

Stable human-readable notes that should survive across runs.

- milestone evaluation notes
- investigation summaries
- verifier findings that should not live only in chat

## Status and Stop Reason Conventions

Recommended `status` values:

- `ready`
- `in_progress`
- `blocked`
- `waiting_on_decision`
- `validated`

Recommended `last_run.stop_reason` values:

- `initialized`
- `milestone_validated`
- `course_corrected`
- `blocked`
- `waiting_on_decision`
- `environment_failure`
- `budget_limit`
- `manual_pause`

Recommended `last_run.events` values:

- `auto_advanced`
- `auto_reframed`
- `course_corrected`

Recommended `validation.type` values:

- `file_check`
- `repo_verification`
- `milestone_evaluation`
- `retry_attempt`
- `plan_review`

## Execution Policy

For Codex App runs that should keep going across multiple milestones, add an `execution` object to `checkpoints.json`.

Suggested fields:

- `mode`: `single_milestone` or `rolling`
- `auto_advance`: whether a validated milestone should advance to the next queued milestone
- `auto_reframe`: whether a low queue should trigger one bounded reframe instead of stopping
- `planning_slice_minutes`: how much planning is allowed before each implementation cycle
- `runtime_budget_minutes`: total run budget for the current session
- `max_milestones_per_run`: optional cap on how many milestones may be advanced in one run
- `reframe_queue_below`: replenish when queued milestones are at or below this count
- `target_queue_depth`: target queued backlog size after a bounded reframe
- `max_reframes_per_run`: cap on bounded reframe passes in one run
- `continue_until`: stop conditions for the current run
- `queued_milestones`: the next milestone IDs and titles in order

Recommended `continue_until` values:

- `blocked`
- `waiting_on_decision`
- `budget_limit`
- `manual_pause`

When a rolling run stops on `budget_limit` or `waiting_on_decision`, preserve the active milestone and remaining `queued_milestones` so the next run can resume instead of re-framing the backlog.

When `auto_advance` is enabled and a milestone validates during a rolling run, record `auto_advanced` in `last_run.events`, advance to the next safe queued milestone, and keep going until a real terminal stop condition is hit.

When `auto_reframe` is enabled and queued milestones fall to or below `reframe_queue_below` while budget remains, spend one bounded planning slice to replenish the backlog toward `target_queue_depth`, record `auto_reframed` in `last_run.events`, and continue from the active or newly chosen safe milestone instead of stopping just because the queue was low.

In rolling mode, reserve `last_run.stop_reason` for the real terminal pause reason such as `budget_limit`, `manual_pause`, `blocked`, or `waiting_on_decision`. Do not use `auto_advanced` or `auto_reframed` as terminal stop reasons when the run continued afterward.

## Blocker Tracking

Track blockers in `checkpoints.json` with:

- `status`
- `type`
- `summary`
- `attempts`
- `next_action`

This prevents silent thrashing across sessions.
