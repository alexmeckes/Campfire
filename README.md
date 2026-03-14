# Campfire

Campfire is a small, reusable harness for long-horizon Codex work.

The core idea is:

- keep the workflow generic
- keep task state on disk
- let project rules live in the project
- make resumption and verification first-class

Instead of one giant project-specific skill, Campfire uses a small stack:

- `task-framer`
- `course-corrector`
- `long-horizon-worker`
- `task-evaluator`
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

### 3. Generic framing skill

`task-framer` turns vague objectives into real Campfire tasks with milestones, acceptance criteria, runbook commands, and the first safe slice.

### 4. Generic course-correction skill

`course-corrector` adjusts the plan when new facts, blockers, or better sequencing emerge during execution.

### 5. Generic evaluator skill

`task-evaluator` checks whether the current milestone is actually complete, records the evaluation result, and either validates the task or sends it back for one more narrow slice.

### 6. Rolling execution policy

Campfire can also run in a rolling mode for Codex App sessions that should keep going while you are away.

In rolling mode:

- planning stays bounded
- the task keeps a machine-readable queued backlog
- evaluation can auto-advance to the next milestone
- the run stops on blockers, decision boundaries, budget limits, or an empty safe backlog
- a budget or decision pause keeps the active milestone and queued backlog intact for the next run

### 7. Project rules

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
- `checkpoints.json.execution`: machine-readable run policy for single-milestone or rolling runs
- `artifacts.json`: manifest of outputs that matter for review or proof

## Codex App Fit

Campfire is designed for Codex App usage:

- the generic skills can be installed globally from this repo
- framing and course-correction can stay generic while project rules stay local
- each repo keeps its own `AGENTS.md`
- each long task gets a durable `.autonomous/<task>/` directory
- Codex App prompts stay short because the state is on disk

## Codex App Launch Patterns

Campfire supports two Codex App launch patterns for rolling runs.

### Live Thread

Use this when you want the work to keep moving in the active Codex App conversation.

- Launch the rolling prompt in the current thread
- Keep the app open and the machine awake
- Codex will keep going until it hits a configured stop condition

### Background Task

Use this when you want the Codex App to run the same rolling task in the background.

- Launch the same rolling prompt as a background task in the app
- Keep the same `.autonomous/<task>/` state and stop conditions
- Use this for “keep going until I get back,” not for recurring schedules

Automations are optional and only matter when you want recurring runs. They are not required for a one-off rolling Codex App task.

Typical prompt:

```text
Use $long-horizon-worker and $task-handoff-state to continue .autonomous/<task>/ and keep working until the current milestone is validated.
```

Typical framing prompt:

```text
Use $task-framer and $task-handoff-state to turn this objective into a concrete Campfire task.
```

Typical course-correction prompt:

```text
Use $course-corrector and $task-handoff-state to update this Campfire task after new information changed the best path.
```

Typical evaluation prompt:

```text
Use $task-evaluator and $task-handoff-state to evaluate whether the current Campfire milestone is actually complete.
```

Typical rolling-run prompt:

```text
Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue .autonomous/<task>/. Keep planning bounded, auto-advance through queued milestones, and stop only on blockers, real decision boundaries, or the configured run budget.
```

## Repo Layout

```text
Campfire/
  skills/
    task-framer/
    course-corrector/
    long-horizon-worker/
    task-evaluator/
    task-handoff-state/
  scripts/
    enable_rolling_mode.sh
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

- `skills/task-framer`
- `skills/course-corrector`
- `skills/long-horizon-worker`
- `skills/task-evaluator`
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
- the blocked/retry verifier passes
- the course-correction verifier passes
- the task-evaluation verifier passes
- the rolling-execution verifier passes
- the rolling budget-limit verifier passes
- the rolling waiting-on-decision verifier passes
- the rolling-mode helper verifier passes

You can also run the lifecycle verifier directly:

```bash
./skills/task-handoff-state/scripts/verify_task_lifecycle.sh
```

And the blocked/retry verifier:

```bash
./skills/task-handoff-state/scripts/verify_blocked_retry.sh
```

And the course-correction verifier:

```bash
./skills/task-handoff-state/scripts/verify_course_correction.sh
```

And the task-evaluation verifier:

```bash
./skills/task-handoff-state/scripts/verify_task_evaluation.sh
```

And the rolling-execution verifier:

```bash
./skills/task-handoff-state/scripts/verify_rolling_execution.sh
```

And the rolling budget-limit verifier:

```bash
./skills/task-handoff-state/scripts/verify_budget_limit.sh
```

And the rolling waiting-on-decision verifier:

```bash
./skills/task-handoff-state/scripts/verify_waiting_on_decision.sh
```

And the rolling-mode helper verifier:

```bash
./skills/task-handoff-state/scripts/verify_enable_rolling_mode.sh
```

## Example Workspace

The example workspace under `examples/basic-workspace/` shows two minimal project-side patterns:

- `AGENTS.md`
- `.autonomous/example-task/`
- `.autonomous/rolling-task/`

Use it as a reference, not as a template you must copy verbatim.

## Quick Start In A Real Project

1. Install the Campfire skills from this repo.
2. Add an `AGENTS.md` file to your project.
3. Create or scaffold a task:

```bash
~/.codex/skills/task-handoff-state/scripts/init_task.sh --root /path/to/project "your objective"
```

If you want the task to keep moving while you are away, switch it into rolling mode:

```bash
~/.codex/skills/task-handoff-state/scripts/enable_rolling_mode.sh --root /path/to/project your-task-slug --queue "milestone-002:Next slice" --queue "milestone-003:Follow-up slice"
```

4. If the task is still vague, prompt:

```text
Use $task-framer and $task-handoff-state to turn this objective into a concrete Campfire task.
```

5. Open the project in Codex App and prompt:

```text
Use $long-horizon-worker and $task-handoff-state to continue .autonomous/<task>/ and keep working until the current milestone is validated.
```

6. If the plan changes mid-run, prompt:

```text
Use $course-corrector and $task-handoff-state to update this task after new facts changed the best path.
```

7. When the milestone seems done, prompt:

```text
Use $task-evaluator and $task-handoff-state to evaluate whether the current milestone is actually complete.
```

8. If you want the Codex app run to keep going while you are away, switch the task to rolling mode and prompt:

```text
Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue .autonomous/<task>/. Keep planning bounded, auto-advance through queued milestones, and stop only on blockers, decision boundaries, or the configured run budget.
```

## Verification

Campfire is meant to be testable, not just described.

The prototype currently uses nine kinds of checks:

- harness smoke tests for scaffold and resume behavior
- lifecycle tests that simulate a validated milestone update end to end
- blocked and retry tests that simulate escalation after repeated failures
- course-correction tests that simulate a real re-plan and verify the new milestone becomes the resume target
- task-evaluation tests that simulate an independent milestone evaluation and validated handoff
- rolling-execution tests that simulate a validated milestone auto-advancing into the next queued milestone
- rolling budget-limit tests that simulate a paused run with queued work still preserved
- rolling waiting-on-decision tests that simulate a paused run at a real decision boundary
- rolling-mode helper tests that simulate converting an existing task into a queued rolling run

The goal is for every Campfire implementation to prove:

- task scaffolding works
- task state upgrades cleanly
- resume output matches on-disk state
- milestone validation can be recorded and surfaced correctly
- blocked and retry state can be surfaced without silent thrashing
- course corrections can update task state without losing continuity
- milestone evaluation can be recorded independently from worker execution
- rolling Codex App runs can advance across multiple milestones without manual restarts
- rolling Codex App runs can pause on budget or decision boundaries without losing the queued backlog

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
- task framing and course correction as first-class skills
- explicit task evaluation as a first-class skill
- durable task-state scaffolding
- lifecycle verifiers for success, blocked retry, course correction, task evaluation, and rolling execution
- explicit rolling stop-condition coverage for budget-limit and waiting-on-decision pauses
- repo-local install and verification scripts
- a minimal example workspace

## Roadmap

- publish the generic skill files
- add reusable task-state verifiers
- add optional worktree-aware bootstrapping for git repos
- document automation patterns for recurring Codex App runs

## Name

Campfire fits the model:

- long-running work that stays warm between runs
- shared handoff state around one task
- a place where logs, artifacts, plans, and next steps gather in one spot
