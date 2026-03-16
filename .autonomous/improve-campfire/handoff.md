# Handoff

## Current Status

- Status: waiting on decision
- Current milestone: `milestone-050` - Add deterministic verification that resume_task.sh surfaces automation proposal guidance correctly
- Next slice: Decision boundary: choose whether Campfire should stay proposal-only, add generic schedule-input scaffolds, or add Codex App-specific automation instantiation support.
- Stop reason: waiting_on_decision

## Resume Prompt

Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, $task-handoff-state, and $task-retrospector to continue this task from `.autonomous/improve-campfire/`. Keep planning bounded, auto-advance through the queued milestones, replenish the queue when policy allows, and keep going until a real blocker, decision boundary, safe-work exhaustion, or an external manual pause appears. Do not impose an internal runtime budget or milestone cap.
