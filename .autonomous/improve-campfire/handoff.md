# Handoff

## Current Status

- Status: ready
- Current milestone: milestone-006 - add a helper script for switching an existing task into rolling mode
- Next slice: implement the rolling-mode helper script and validate it before auto-advancing to the next queued milestone
- Stop reason: auto_advanced

## Resume Prompt

Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue this task from `.autonomous/improve-campfire/`. Keep planning bounded, auto-advance through the queued milestones, and stop only on a real blocker, decision boundary, budget limit, or manual pause.
