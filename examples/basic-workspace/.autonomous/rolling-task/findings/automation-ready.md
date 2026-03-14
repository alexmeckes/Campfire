# automation-ready patterns

- Generate the current task-only prompt bodies with:
  `~/.codex/skills/task-handoff-state/scripts/automation_prompt_helper.sh rolling-task`
- Nightly rolling resume:
  `Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue .autonomous/rolling-task/. Keep planning bounded, auto-advance through queued milestones, replenish the queue when policy allows and budget remains, update task state after each meaningful slice, and stop only on a real blocker, decision boundary, budget limit, or manual pause.`
- Verifier sweep:
  `Use $task-evaluator and $task-handoff-state to inspect .autonomous/rolling-task/, rerun the strongest validation in runbook.md, refresh findings only if evidence changed, and stop after updating task state.`
- Backlog refresh:
  `Use $task-framer, $course-corrector, and $task-handoff-state to review .autonomous/rolling-task/, tighten the next 2 to 3 milestones, refresh execution policy if needed, preserve prior progress, and leave a new handoff without broad implementation unless the new next slice is obvious and dependency-safe.`
- Workspace rule: schedule and workspace selection belong in the automation config, not in the prompt body.
