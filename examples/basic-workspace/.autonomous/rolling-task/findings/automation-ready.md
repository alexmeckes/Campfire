# automation-ready patterns

- Nightly rolling resume:
  `Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue .autonomous/rolling-task/. Keep planning bounded, auto-advance through queued milestones, replenish the queue when policy allows and budget remains, update task state after each meaningful slice, and stop only on a real blocker, decision boundary, budget limit, or manual pause.`
- Verifier sweep:
  `Use $task-evaluator and $task-handoff-state to inspect .autonomous/rolling-task/, rerun the strongest validation in runbook.md, refresh findings only if evidence changed, and stop after updating task state.`
- Workspace rule: schedule and workspace selection belong in the automation config, not in the prompt body.
