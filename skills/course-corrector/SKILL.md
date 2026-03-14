---
name: course-corrector
description: Use when a running Campfire task needs to adjust course because new facts, blockers, better sequencing, or changed constraints were discovered. Re-plans without losing task history, updates milestones and runbooks, and records why the course changed.
---

# Course Corrector

Use this skill when a Campfire task has learned something important and the plan should change.

This skill is for re-planning without losing continuity. Pair it with:

- `$task-handoff-state` for the durable file contract
- `$long-horizon-worker` after the task is re-aimed

Read [references/course-correction-triggers.md](references/course-correction-triggers.md) when you need the trigger list and rewrite rules.

## When To Use

Use this skill when:

- a blocker changed the feasible path
- a better sequence became obvious
- acceptance criteria were too weak or too strong
- a new source doc changes what done means
- the task should split into multiple tasks
- the current milestone is no longer the right next milestone

Do not use it just because a task is hard. Use it when the plan itself needs to change.

## Course Correction Workflow

1. Read current task state:
   - `plan.md`
   - `runbook.md`
   - `progress.md`
   - `handoff.md`
   - `checkpoints.json`
   - `artifacts.json`
2. Identify the new fact, blocker, or sequencing insight that requires change.
3. Preserve history in `progress.md`.
4. Rewrite only the forward-looking pieces:
   - milestone ordering
   - acceptance criteria
   - blocker state
   - runbook commands
   - execution queue and run budget assumptions
   - next slice
5. Update `handoff.md` and `checkpoints.json` so the next run resumes from the corrected plan instead of the stale one.

## Guardrails

- Do not erase prior progress.
- Do not rewrite the whole task just because one slice failed.
- If the task is now materially different, create a new task instead of overloading the old one.
- Record the reason for the course change in `progress.md` and `checkpoints.json`.

## Good Corrections

A good course correction makes these things clearer:

- what changed
- why the old path is no longer best
- what the new current milestone is
- what the new queued milestones are, if rolling mode is active
- what the new next slice is
- whether the task is blocked, waiting on a decision, or ready again

## Output Style

- Keep the explanation factual.
- Update the task files first.
- In the final response, summarize the correction reason, the new milestone, and the new next slice.
