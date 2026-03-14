# Campfire

Campfire is a simple pattern for long-horizon Codex work.

The core idea is:

- keep the workflow generic
- keep task state on disk
- let project rules live in the project
- make resumption and verification first-class

Instead of one giant project-specific skill, Campfire uses a small stack:

- `long-horizon-worker`
- `task-handoff-state`
- `AGENTS.md` in each repo
- `.autonomous/<task>/` as the durable task directory

## Why

Long-running Codex work usually fails for predictable reasons:

- the objective drifts
- prior decisions disappear into chat history
- validation is vague
- resumption is manual and lossy
- project-specific rules get mixed into generic workflow logic

Campfire separates those concerns.

The skills define how work should proceed.
The repo defines what matters for that project.
The task directory records the current state in a form that survives restarts, background runs, handoffs, and automation.

## Model

Campfire treats a long-running task as a small harness, not a giant prompt.

### 1. Generic execution skill

`long-horizon-worker` owns the loop:

- pick one dependency-safe slice
- make the smallest useful change
- validate immediately
- update task state
- stop only on validation, blocker, or real decision boundary

### 2. Generic task-state skill

`task-handoff-state` owns the durable file contract under `.autonomous/<task>/`.

### 3. Project rules

Project-specific guidance belongs in:

- `AGENTS.md`
- project docs
- task-local notes in `runbook.md`

## Task State Contract

Each task lives under:

```text
.autonomous/<task>/
  plan.md
  runbook.md
  progress.md
  handoff.md
  checkpoints.json
  artifacts.json
  logs/
  artifacts/
  findings/
```

### File purposes

- `plan.md`: stable objective, source docs, milestones, assumptions
- `runbook.md`: setup, boot, validation, observability, required tools
- `progress.md`: append-only log of changes, validation, blockers, next slice
- `handoff.md`: concise resume note with current status and stop reason
- `checkpoints.json`: machine-readable task state for resumption and automation
- `artifacts.json`: manifest of outputs that matter for review or proof

## Codex App Fit

Campfire is designed for Codex App usage:

- the two generic skills are installed globally
- each repo keeps its own `AGENTS.md`
- each long task gets a durable `.autonomous/<task>/` directory
- Codex App prompts stay short because the state is on disk

Typical prompt:

```text
Use $long-horizon-worker and $task-handoff-state to continue .autonomous/<task>/ and keep working until the current milestone is validated.
```

## Verification

Campfire is meant to be testable, not just described.

The prototype currently uses two kinds of checks:

- harness smoke tests for scaffold and resume behavior
- lifecycle tests that simulate a validated milestone update end to end

The goal is for every Campfire implementation to prove:

- task scaffolding works
- task state upgrades cleanly
- resume output matches on-disk state
- milestone validation can be recorded and surfaced correctly

## Principles

- Keep the skill small and the harness strong.
- Keep project rules out of the global workflow skill.
- Write state to disk, not only to chat.
- Make validation explicit.
- Prefer bounded resumable runs over one immortal session.
- Track blockers and stop reasons so the agent does not thrash.

## Current Status

Campfire is an emerging pattern, not a finished framework.

The current implementation direction is:

- portable generic Codex skills
- durable task-state scaffolding
- repo-local wrappers and verification scripts
- optional project-specific overlays only when they add real value

## Roadmap

- publish the generic skill files
- add reusable task-state verifiers
- add blocked-run and retry-path verification
- add optional worktree-aware bootstrapping for git repos
- document automation patterns for recurring Codex App runs

## Name

Campfire fits the model:

- long-running work that stays warm between runs
- shared handoff state around one task
- a place where logs, artifacts, plans, and next steps gather in one spot
