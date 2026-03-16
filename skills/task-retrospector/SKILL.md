---
name: task-retrospector
description: Use when a Campfire task, benchmark run, or repeated workflow failure should be turned into explicit improvement actions. Reviews what happened, identifies wasted motion or drift, and converts the result into benchmark, verifier, skill, wrapper, or doc follow-up candidates.
---

# Task Retrospector

Use this skill after a meaningful Campfire run when you want the workflow to improve over time without relying on vague "memory."

This skill is for structured learning, not generic journaling.

Pair it with:

- `$task-handoff-state` to read durable task state
- `$task-evaluator` when a milestone result needs independent interpretation
- `$course-corrector` when the task plan itself should change

Read [references/retrospective-checklist.md](references/retrospective-checklist.md) when you need the retrospective checklist and output rules.
Read [/Users/alexmeckes/Downloads/Campfire/docs/campfire-generated-skills.md](/Users/alexmeckes/Downloads/Campfire/docs/campfire-generated-skills.md) when a retrospective should propose a generated micro-skill instead of a verifier, benchmark, or control-plane change.
Use [/Users/alexmeckes/Downloads/Campfire/skills/task-handoff-state/scripts/record_improvement_candidate.sh](/Users/alexmeckes/Downloads/Campfire/skills/task-handoff-state/scripts/record_improvement_candidate.sh) when you want the retrospective result stored mechanically in the SQL improvement backlog instead of only in prose.
Use [/Users/alexmeckes/Downloads/Campfire/skills/task-handoff-state/scripts/promote_improvement.sh](/Users/alexmeckes/Downloads/Campfire/skills/task-handoff-state/scripts/promote_improvement.sh) when a reviewed candidate should become a real follow-up task.

## When To Use

Use this skill when:

- a task completed and you want to capture what should improve next time
- a task failed, drifted, or burned unnecessary overhead
- a repeated blocker or repeated bad pattern appears across tasks
- a benchmark regression should become a concrete Campfire improvement item

Do not use it for normal implementation. Use it after a task or benchmark run has produced enough evidence to learn from.

## Retrospective Workflow

1. Read only the task state and evidence that matter:
   - `checkpoints.json`
   - `handoff.md`
   - `progress.md`
   - `artifacts.json`
   - relevant `findings/`
   - benchmark result files when applicable
2. Identify the key outcome:
   - success with friction
   - success with drift
   - blocked
   - failed validation
   - benchmark regression
3. Extract the highest-signal issues only:
   - repeated wasted motion
   - state drift
   - missing guardrails
   - validation weakness
   - prompt dependence
   - documentation ambiguity
4. Classify each issue into one concrete follow-up type:
   - benchmark candidate
   - verifier candidate
   - skill change
   - wrapper/control-plane change
   - repo-specific lesson
5. Write a short retrospective note under `findings/`, usually `findings/<task-slug>-retrospective.md` or `findings/<milestone-id>-retrospective.md`.
6. If useful, write a machine-readable companion such as `findings/<name>-improvement-candidates.json` and mirror the same candidate into the SQL improvement backlog with `record_improvement_candidate.sh`.
7. Update task state only if the retrospective materially changes the next queued work.

For `skill_candidate` outputs, prefer candidate creation over immediate promotion. Task-local or repo-local drafts are the default; Campfire-core promotion should remain benchmark-backed and explicit.

## Minimum Good Output

A good retrospective answers:

- What happened?
- What was the main source of waste, fragility, or drift?
- Is this a one-off or a reusable pattern?
- What exact Campfire surface should change?
- What is the smallest next action that would improve the system?

## Classification Rules

Prefer one of these outputs per issue:

- `benchmark_candidate`
  - when the failure mode should be measured repeatedly
- `verifier_candidate`
  - when Campfire should fail earlier or more explicitly
- `skill_candidate`
  - when the model instructions are too weak or ambiguous
- `control_plane_candidate`
  - when the fix should become a script, DB field, registry field, or lifecycle transition
- `repo_lesson`
  - when the insight is local to one consumer repo

## Guardrails

- Do not produce a long narrative recap.
- Do not create improvement work without tying it to concrete evidence.
- Prefer benchmark or verifier changes over vague “agent should do better” language.
- Keep lessons explicit and reviewable.
- If no reusable lesson exists, say so plainly.

## Output Style

- Write the retrospective artifact first.
- In the final response, summarize the top one to three reusable findings and the exact follow-up category for each.
