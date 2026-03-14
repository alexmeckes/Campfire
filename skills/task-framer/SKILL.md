---
name: task-framer
description: Use when a vague objective needs to become a real Campfire task. Inspects the workspace, finds project rules and source docs, creates or upgrades `.autonomous/<task>/`, and turns the objective into milestones, acceptance criteria, runbook commands, risks, and the first safe slice.
---

# Task Framer

Use this skill when the user has a goal, but the Campfire task is still underspecified.

This skill turns a vague objective into a usable Campfire task. Pair it with:

- `$task-handoff-state` to create or normalize the task files
- `$long-horizon-worker` after the task is framed

Read [references/framing-checklist.md](references/framing-checklist.md) when you need the framing checklist and output expectations.

## When To Use

Use this skill for:

- a new long-horizon task with no real milestone structure yet
- placeholder `plan.md` or `runbook.md` files that need real content
- broad requests like `build this`, `refactor this`, or `research this`
- preparing a task for automation or background continuation

Do not use it when the task is already well-framed and the next slice is obvious.

## Framing Workflow

1. Read `AGENTS.md` if present.
2. Inspect the repo shape and identify likely source-of-truth docs.
3. Ensure `.autonomous/<task>/` exists, using `$task-handoff-state` if needed.
4. Rewrite the task state so it is specific enough to execute:
   - `plan.md`
   - `runbook.md`
   - `handoff.md`
   - `checkpoints.json`
   - `artifacts.json` when there are already expected outputs
5. Define:
   - milestone IDs and titles
   - milestone ordering and dependencies
   - acceptance criteria
   - expected validation commands or evidence
   - likely blockers or decision boundaries
   - the first dependency-safe slice
   - rolling execution policy when the task should keep going unattended

## Minimum Good Output

A framed task should answer:

- What is the real objective?
- Which docs or files define correctness?
- What are the next 3 to 5 milestones?
- How will each milestone be verified?
- What is the next safe slice right now?

## Planning Rules

- Prefer milestones that are independently verifiable.
- Keep milestone titles stable and short.
- Keep acceptance criteria concrete and testable.
- If setup or validation is unknown, write that explicitly into `runbook.md`.
- If a major product decision is still unresolved, mark it as a decision boundary instead of inventing certainty.
- For Codex App background or unattended runs, frame at least the next 2 to 3 milestones and write an `execution` policy into `checkpoints.json`.
- In rolling mode, set a planning budget, runtime budget, queued milestones, and explicit stop conditions instead of relying on “stop after one validated milestone.”

## Output Style

- Update the task files, do not leave the framing only in chat.
- In the final response, summarize the new milestones, the first slice, and any decision boundaries.
