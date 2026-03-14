# Handoff

## Current Status

- Status: ready
- Current milestone: milestone-024 - add an automation prompt helper that emits task-only recurring prompt variants from Campfire state
- Next slice: add a helper under `skills/task-handoff-state/scripts/` that prints `rolling_resume`, `verifier_sweep`, and `backlog_refresh` prompt variants for an existing task slug without mixing schedule or workspace into the prompt body
- Stop reason: manual_pause

## Resume Prompt

Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue this task from `.autonomous/improve-campfire/`. Keep planning bounded, auto-advance through the queued milestones, replenish the queue when policy allows, and keep going until a real blocker, decision boundary, safe-work exhaustion, or an external manual pause appears. Do not impose an internal runtime budget or milestone cap.
