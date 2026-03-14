# Handoff

## Current Status

- Status: ready
- Current milestone: milestone-029 - add an automation proposal helper that emits a suggested automation name and task-only prompt from Campfire state
- Next slice: add a helper under `skills/task-handoff-state/scripts/` that prints a suggested automation name plus task-only prompt proposal fields for an existing task slug without embedding schedule or workspace settings
- Stop reason: manual_pause

## Resume Prompt

Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue this task from `.autonomous/improve-campfire/`. Keep planning bounded, auto-advance through the queued milestones, replenish the queue when policy allows, and keep going until a real blocker, decision boundary, safe-work exhaustion, or an external manual pause appears. Do not impose an internal runtime budget or milestone cap.
