# Handoff

## Current Status

- Status: validated
- Current milestone: milestone-014 - document dynamic rolling queue replenishment for Codex App runs
- Next slice: choose the next Campfire improvement milestone
- Stop reason: milestone_validated

## Resume Prompt

Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue this task from `.autonomous/improve-campfire/`. Frame the next rolling backlog if needed, then keep planning bounded, auto-advance through queued milestones, replenish the queue when policy allows and budget remains, and stop only on a real blocker, decision boundary, budget limit, or manual pause.
