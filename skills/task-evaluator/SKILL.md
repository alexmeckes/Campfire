---
name: task-evaluator
description: Use when a Campfire task needs an independent evaluation pass before marking the current milestone complete. Checks acceptance criteria against validation evidence, artifacts, and changed files, then records either validated status or the next required slice.
---

# Task Evaluator

Use this skill when a Campfire task appears done and needs an explicit evaluation pass before the milestone should be treated as complete.

This skill closes the loop between execution and final validation. Pair it with:

- `$task-handoff-state` for durable state updates
- `$long-horizon-worker` when evaluation finds more work
- `$course-corrector` when evaluation shows the plan itself should change

Read [references/evaluation-checklist.md](references/evaluation-checklist.md) when you need the evaluation checklist and outcome rules.

## When To Use

Use this skill when:

- the worker believes the current milestone is complete
- a handoff or automation needs an explicit yes or no on milestone completion
- validation exists but the acceptance criteria have not been independently checked
- the task needs a narrow next slice instead of a vague `keep going`

Do not use it as a replacement for implementation. Use it to judge whether implementation has actually met the current milestone.

## Evaluation Workflow

1. Read the current task state:
   - `plan.md`
   - `runbook.md`
   - `progress.md`
   - `handoff.md`
   - `checkpoints.json`
   - `artifacts.json`
2. Identify the active milestone and its acceptance criteria from `checkpoints.json`.
3. Inspect only the files, artifacts, and validation outputs relevant to that milestone.
4. Re-run or spot-check the strongest available validation when practical.
5. Compare each acceptance criterion against concrete evidence.
6. Write an evaluation note under `findings/`, usually `findings/<milestone-id>-evaluation.md`.
7. Update task state:
   - mark the milestone `validated` only if the evidence is real and sufficient
   - otherwise record the missing proof or missing implementation and set the next slice
   - if the milestone itself is wrong, hand off to `$course-corrector`
   - if `execution.mode` is `rolling` and `auto_advance` is enabled, record `auto_advanced` in `last_run.events`, advance to the next queued milestone, and continue
   - if rolling mode is active and the queue has dropped below the configured threshold, replenish it with one bounded framing pass, record `auto_reframed` in `last_run.events`, and continue unless a real stop condition is hit

## Minimum Good Output

A good evaluation answers:

- What milestone was evaluated?
- Which acceptance criteria passed?
- What evidence supports each passed criterion?
- What is still missing, if anything?
- Is the task validated, still ready, blocked, or in need of course correction?

## Guardrails

- Do not just repeat the worker summary.
- If a criterion lacks evidence, treat it as unmet.
- Prefer a narrow follow-up slice over a broad critique.
- Keep the evaluation independent from the implementation narrative.
- Record the evaluation artifact in `artifacts.json`.
- In rolling mode, validation should normally move the task to the next queued milestone instead of leaving it parked on the one that just passed.
- In dynamic rolling mode, do not stop on an empty queue until a permitted bounded reframe has either replenished it or failed to find a safe next milestone.
- In rolling mode, keep `last_run.stop_reason` for the actual terminal pause reason. Treat `auto_advanced` and `auto_reframed` as run events.

## Output Style

- Update the task files first.
- In the final response, summarize the evaluation result, strongest evidence, and next slice if the milestone is not validated.
