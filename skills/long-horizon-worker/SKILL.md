---
name: long-horizon-worker
description: Use when Codex should keep advancing a multi-step task across long or repeated runs. Coordinates bounded implementation slices, validation after each slice, checkpoint updates, and concise handoffs. Pair with task-handoff-state for durable task state.
---

# Long Horizon Worker

Use this skill when the user wants Codex to keep moving on a task without repeated confirmation, especially across multiple Codex App runs, background sessions, or recurring automations.

This skill does not own project knowledge. It owns the operating loop. Project-specific rules should stay in:

- `AGENTS.md`
- repo docs
- task files under `.autonomous/<task>/`

Pair this skill with `$task-handoff-state` whenever the task needs durable state.

If `checkpoints.json` contains an `execution.mode` of `rolling`, treat the task as a rolling Codex App run rather than a single-milestone pass.

## When To Use

Use this skill for:

- long-running implementation work
- multi-session debugging or refactors
- recurring automation-style tasks
- prompts like `keep going`, `continue until validated`, or `work through the backlog`

Do not use it for one-shot factual questions or tasks that depend on repeated human taste decisions.
Do not reinterpret a missing continue target as permission to create a new task in the current workspace.

## Quick Start

1. Confirm the active workspace.
2. Read `AGENTS.md` if present.
3. If `.autonomous/<task>/` does not exist:
   - for a new task request, use `$task-handoff-state` or run the companion task-state initializer
   - for a continue or resume request against a named task, stop and report the missing task state instead of initializing a replacement
4. Read the task state:
   - `plan.md`
   - `runbook.md`
   - `progress.md`
   - `handoff.md`
   - `checkpoints.json`
   - `artifacts.json`
5. Identify the next dependency-safe slice.
6. Make the smallest useful change set, validate it, and update task state before moving on.

## Rolling Run Mode

Use rolling mode when the user wants Codex to keep going until they return, a blocker appears, or a run budget expires. Use `run_style: until_stopped` when the user explicitly wants the run to continue until they manually stop it.

When `checkpoints.json` has an `execution` object with:

- `mode: rolling`
- `auto_advance: true`

follow these extra rules:

1. Keep planning bounded to `planning_slice_minutes`.
2. Maintain a queued backlog of the next milestones in `execution.queued_milestones`.
3. After a milestone validates, use `$task-evaluator` logic to confirm it and then advance to the next queued milestone instead of stopping.
4. Update `checkpoints.json`, `handoff.md`, and `progress.md` at each milestone boundary.
5. If `auto_reframe` is enabled and the queue depth falls to or below `reframe_queue_below` while run budget remains, spend one bounded planning slice to replenish the backlog toward `target_queue_depth`.
6. Record `auto_advanced` and `auto_reframed` as run events in task state instead of using them as terminal stop reasons when the run continues.
7. After a bounded reframe succeeds and budget remains, continue execution from the active or newly chosen safe milestone instead of stopping just because the queue had been low.
8. If `min_runtime_minutes` or `min_milestones_per_run` are set, do not choose a voluntary `manual_pause` before those floors are met unless a blocker, decision boundary, or budget limit forces a real stop.
9. Stop only when:
   - a configured `continue_until` condition is hit
   - the runtime budget expires for `run_style: bounded`
   - the queued backlog is empty and no safe next milestone can be chosen even after a permitted bounded reframe

When `run_style: until_stopped` is active:

- treat `runtime_budget_minutes: 0` as no internal budget
- treat `max_milestones_per_run: 0` as no milestone cap
- treat `max_reframes_per_run: 0` as no reframe cap
- do not stop on `budget_limit` unless the task explicitly chose a bounded run style instead
- continue replenishing the queue with bounded reframes as long as safe work remains

In rolling mode, validation is not the default stop condition. It is the trigger for advancing to the next milestone when allowed.
In dynamic rolling mode, low queue depth is the trigger for one bounded reframe when the execution policy allows it.
In rolling mode, `auto_advanced` and `auto_reframed` are mid-run transitions. Reserve `last_run.stop_reason` for the actual terminal pause reason.
In autonomous rolling mode, `manual_pause` should be treated as external-only unless the run has already satisfied its configured minimum runtime and milestone floor.
In `run_style: until_stopped`, do not invent a “clean pause” after a good batch. Keep going until a real blocker, decision boundary, safe-work exhaustion, or an external manual pause occurs.

## Loop Contract

For each iteration:

1. Restate the current milestone in one sentence.
2. Choose exactly one concrete slice.
3. Inspect only the files and docs needed for that slice.
4. Make the smallest meaningful change set.
5. Validate immediately with the strongest available evidence.
6. Update task state before broadening scope.

## Validation Ladder

Prefer validation in this order:

1. targeted file or data inspection
2. test or lint execution
3. framework-specific validation tools
4. runtime launch and structured error inspection
5. screenshots or recorded artifacts for visible claims

Never mark a milestone complete without writing validation evidence into task state.

## Task-State Expectations

The task directory should contain:

- `plan.md`
- `runbook.md`
- `progress.md`
- `handoff.md`
- `checkpoints.json`
- `artifacts.json`
- `logs/`
- `artifacts/`
- `findings/`

Write to those files as you go instead of leaving the state only in chat.

## Isolation Strategy

- If the workspace is a git repo and the task is risky or long-lived, prefer a dedicated worktree.
- If the workspace is not a git repo, use the workspace directly and keep artifacts inside `.autonomous/<task>/`.
- Keep temporary reasoning or collection output in task-local files, not in unrelated project folders.

## Stop Conditions

Continue until one of these is true:

- the current milestone is implemented and validated
- the next step requires a user decision that cannot be safely assumed
- the environment blocks further progress

If `execution.mode` is `rolling`, replace the first rule with:

- the current milestone is implemented and validated and the run policy says to stop instead of auto-advance
- or the rolling backlog is exhausted and no safe next milestone can be chosen even after a permitted bounded reframe

If a bounded reframe replenishes the backlog successfully and budget remains, that is not a stop condition by itself.
If the run has not yet met `min_runtime_minutes` or `min_milestones_per_run`, that is also not a stop condition by itself.

If the same validation failure repeats twice, stop broadening scope. Fix the failure or report the blocker.

## Output Style

- Commentary updates should be short and factual.
- Every meaningful run should leave a handoff in `.autonomous/<task>/handoff.md`.
- Final answers should summarize what changed, what validation passed, and the next slice.
