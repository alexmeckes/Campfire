# Handoff

## Current Status

- Status: ready
- Current milestone: milestone-002 - Continue after the first auto-advance
- Next slice: implement milestone-002 while the rolling run budget remains
- Stop reason: manual_pause

## Resume Prompt

Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue this task from `.autonomous/rolling-task/`. Keep planning bounded, auto-advance through the queued milestones, replenish the queue when policy allows and budget remains, do not self-pause before the configured minimum runtime and milestone floor unless a blocker or decision boundary appears, and stop only on a real blocker, decision boundary, budget limit, or an external manual pause.
