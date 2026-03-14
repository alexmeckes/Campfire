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
- `blocker`
- `last_run`
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

Recommended `validation.type` values:

- `file_check`
- `repo_verification`
- `milestone_evaluation`
- `retry_attempt`
- `plan_review`

## Blocker Tracking

Track blockers in `checkpoints.json` with:

- `status`
- `type`
- `summary`
- `attempts`
- `next_action`

This prevents silent thrashing across sessions.
