# Task State Contract

This reference defines the durable file contract for `.autonomous/<task>/`.

## Core Files

- `plan.md`
- `runbook.md`
- `progress.md`
- `handoff.md`
- `checkpoints.json`
- `artifacts.json`
- `logs/`
- `artifacts/`
- `findings/`

## Runtime-Managed Files

- `heartbeat.json`
- `logs/session.log`

`heartbeat.json` and `logs/session.log` should exist after the task passes through `init_task.sh`, `start_slice.sh`, or `complete_slice.sh`. Older or fixture tasks may be missing them until they are normalized through the current lifecycle helpers.

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

When a run starts a new implementation slice, update `checkpoints.json.status` to `in_progress`, advance `current` to the active milestone/slice, and mirror that slice in `handoff.md` before touching project files. This keeps boards and resumptions aligned with the real work in flight.
Use a deterministic helper such as `start_slice.sh` when possible so this transition does not depend on the model remembering to do it manually.

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

### `heartbeat.json`

Machine-readable liveness for the active task session.

- `state`
- `session_started_at`
- `last_seen_at`
- `milestone_id`
- `milestone_title`
- `slice_id`
- `slice_title`
- `summary`
- `touched_path`
- `source`

Recommended `state` values:

- `active`
- `idle`
- `blocked`
- `waiting_on_decision`
- `completed`

Mirror each heartbeat update into `logs/session.log` as one JSON line so operators can inspect a single append-only activity trail.

### Repo-local registry

Maintain `.campfire/registry.json` at the repo root as the lightweight control-plane summary.

- one entry per `.autonomous/<task>/`
- current status and phase
- current milestone and slice
- queued count
- last run summary
- heartbeat state and last seen timestamp

Boards and watchdogs should prefer this registry when it exists instead of rediscovering task state from scratch.

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
- `completed`

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
- `slice_started`
- `slice_completed`

Recommended `validation.type` values:

- `file_check`
- `repo_verification`
- `milestone_evaluation`
- `retry_attempt`
- `plan_review`
- `registry_refresh`

## Execution Policy

For Codex App runs that should keep going across multiple milestones, add an `execution` object to `checkpoints.json`.

Suggested fields:

- `mode`: `single_milestone` or `rolling`
- `run_style`: `bounded` or `until_stopped`
- `auto_advance`: whether a validated milestone should advance to the next queued milestone
- `auto_reframe`: whether a low queue should trigger one bounded reframe instead of stopping
- `planning_slice_minutes`: how much planning is allowed before each implementation cycle
- `runtime_budget_minutes`: total run budget for the current session; use `0` for no internal budget in `until_stopped` runs
- `min_runtime_minutes`: minimum autonomous runtime target before the worker may voluntarily self-pause
- `min_milestones_per_run`: minimum number of milestone transitions to aim for before voluntarily self-pausing
- `max_milestones_per_run`: optional cap on how many milestones may be advanced in one run; use `0` for no cap
- `reframe_queue_below`: replenish when queued milestones are at or below this count
- `target_queue_depth`: target queued backlog size after a bounded reframe
- `max_reframes_per_run`: cap on bounded reframe passes in one run; use `0` for no cap
- `continue_until`: stop conditions for the current run
- `queued_milestones`: the next milestone IDs and titles in order

Recommended `continue_until` values for autonomous rolling runs:

- `blocked`
- `waiting_on_decision`
- `budget_limit`

For `run_style: until_stopped`, remove `budget_limit` from `continue_until`, set `runtime_budget_minutes: 0`, and remove internal milestone/reframe caps unless you explicitly need them.

Use `manual_pause` only for an explicit user pause or an externally interrupted run. Do not treat it as a normal autonomous stop trigger.

When a rolling run stops on `budget_limit` or `waiting_on_decision`, preserve the active milestone and remaining `queued_milestones` so the next run can resume instead of re-framing the backlog.

When `auto_advance` is enabled and a milestone validates during a rolling run, record `auto_advanced` in `last_run.events`, advance to the next safe queued milestone, and keep going until a real terminal stop condition is hit.

When `auto_reframe` is enabled and queued milestones fall to or below `reframe_queue_below` while budget remains, spend one bounded planning slice to replenish the backlog toward `target_queue_depth`, record `auto_reframed` in `last_run.events`, and continue from the active or newly chosen safe milestone instead of stopping just because the queue was low.

When `min_runtime_minutes` or `min_milestones_per_run` are set for an autonomous rolling run, do not voluntarily stop on `manual_pause` before those floors are met unless the task becomes `blocked`, hits `waiting_on_decision`, or exhausts the run budget.

In rolling mode, reserve `last_run.stop_reason` for the real terminal pause reason such as `budget_limit`, `manual_pause`, `blocked`, or `waiting_on_decision`. Do not use `auto_advanced` or `auto_reframed` as terminal stop reasons when the run continued afterward.

For `run_style: until_stopped`, a normal autonomous stop should happen only when the task is `blocked`, reaches `waiting_on_decision`, or exhausts the current safe backlog even after any permitted bounded reframe. `manual_pause` stays external-only.

## Blocker Tracking

Track blockers in `checkpoints.json` with:

- `status`
- `type`
- `summary`
- `attempts`
- `next_action`

This prevents silent thrashing across sessions.

## Missing Resume Targets

If a user asks to continue or resume a specific `.autonomous/<task>/` and that task directory is missing in the current workspace:

- treat it as missing state or a likely workspace mismatch
- stop and surface the problem
- do not silently create or bootstrap a replacement task

Only initialize a new task when the user explicitly asks to create or frame one.
