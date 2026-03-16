# Handoff

## Current Status

- Status: ready
- Current milestone: milestone-039 - add a prompt-template layer for canonical Campfire operator flows
- Next slice: define a small reusable template format and add canonical resume, retrospective, benchmark, and improvement-promotion templates without duplicating large markdown prompt blocks
- Stop reason: course_corrected

## Resume Prompt

Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, $task-handoff-state, and $task-retrospector to continue this task from `.autonomous/improve-campfire/`. Keep planning bounded, auto-advance through the queued milestones, replenish the queue when policy allows, and keep going until a real blocker, decision boundary, safe-work exhaustion, or an external manual pause appears. Do not impose an internal runtime budget or milestone cap.
