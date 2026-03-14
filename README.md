# Campfire

Campfire is a small, reusable harness for long-horizon Codex work.

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

This repo now contains the actual generic skill files, bundled scripts, an installer, and an example workspace.

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

- the two generic skills can be installed globally from this repo
- each repo keeps its own `AGENTS.md`
- each long task gets a durable `.autonomous/<task>/` directory
- Codex App prompts stay short because the state is on disk

Typical prompt:

```text
Use $long-horizon-worker and $task-handoff-state to continue .autonomous/<task>/ and keep working until the current milestone is validated.
```

## Repo Layout

```text
Campfire/
  skills/
    long-horizon-worker/
    task-handoff-state/
  scripts/
    install_skills.sh
    verify_repo.sh
  examples/
    basic-workspace/
```

## Install

Install the Campfire skills into `~/.codex/skills`:

```bash
./scripts/install_skills.sh
```

That script symlinks:

- `skills/long-horizon-worker`
- `skills/task-handoff-state`

into your Codex skills directory and backs up conflicting existing skill folders.

Restart Codex App after installation so the skill list refreshes.

## Verify

Verify the repo itself:

```bash
./scripts/verify_repo.sh
```

This checks:

- skill files and metadata exist
- shell scripts parse
- the example workspace exists
- the generic lifecycle verifier passes

You can also run the lifecycle verifier directly:

```bash
./skills/task-handoff-state/scripts/verify_task_lifecycle.sh
```

## Example Workspace

The example workspace under `examples/basic-workspace/` shows the minimal project-side pieces:

- `AGENTS.md`
- `.autonomous/example-task/`

Use it as a reference, not as a template you must copy verbatim.

## Quick Start In A Real Project

1. Install the Campfire skills from this repo.
2. Add an `AGENTS.md` file to your project.
3. Create a task:

```bash
~/.codex/skills/task-handoff-state/scripts/init_task.sh --root /path/to/project "your objective"
```

4. Open the project in Codex App and prompt:

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

Campfire is early, but it is now concrete enough to install and test:

- portable generic Codex skills
- durable task-state scaffolding
- repo-local install and verification scripts
- a minimal example workspace

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
