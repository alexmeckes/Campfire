# milestone-028 evaluation

Evaluated the automation-helper backlog covering milestones 024 through 028.

## Result

Validated.

## Evidence

1. Milestone-024 passed: Campfire now has a reusable prompt helper at `skills/task-handoff-state/scripts/automation_prompt_helper.sh` that emits `rolling_resume`, `verifier_sweep`, and `backlog_refresh` prompts from task state.
   - Evidence: `./skills/task-handoff-state/scripts/automation_prompt_helper.sh --root /Users/alexmeckes/Downloads/Campfire improve-campfire`
2. Milestone-025 passed: deterministic verification exists for bounded and `until_stopped` task-state selection.
   - Evidence: `./skills/task-handoff-state/scripts/verify_automation_prompt_helper.sh`
3. Milestone-026 passed: the helper is documented in `README.md`, `skills/task-handoff-state/SKILL.md`, `skills/task-handoff-state/references/automation-patterns.md`, `examples/basic-workspace/AGENTS.md`, and `examples/basic-workspace/.autonomous/rolling-task/findings/automation-ready.md`.
4. Milestone-027 passed: `skills/task-handoff-state/scripts/resume_task.sh` now surfaces automation prompt variants for rolling tasks instead of requiring copied examples.
5. Milestone-028 passed: deterministic verification proves `resume_task.sh` exposes the automation-helper guidance for rolling tasks.
   - Evidence: `./skills/task-handoff-state/scripts/verify_resume_automation_prompt_guidance.sh`
6. Repo-wide validation passed after the helper, verifier, docs, and resume integration landed.
   - Evidence: `./scripts/verify_repo.sh`

## Notes

- The helper keeps the automation prompt body task-only by targeting `.autonomous/<task>/` and not embedding schedule or workspace settings.
- The next leverage point is generating suggested automation proposal metadata from the same task state so Codex App recurring runs can be scaffolded with less manual setup.
