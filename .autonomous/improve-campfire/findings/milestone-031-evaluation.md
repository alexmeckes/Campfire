# milestone-031 evaluation

Evaluated the missing-resume guardrail backlog covering the urgent follow-up after the fresh-thread workspace mismatch.

## Result

Validated.

## Evidence

1. `resume_task.sh` now fails with explicit guidance when a requested task slug is missing in the current workspace.
   - Evidence: `./skills/task-handoff-state/scripts/verify_missing_resume_guardrail.sh`
2. The task-state, framer, and worker skills now explicitly forbid silently bootstrapping a replacement task from a continue/resume request.
   - Evidence: `skills/task-handoff-state/SKILL.md`, `skills/task-framer/SKILL.md`, `skills/long-horizon-worker/SKILL.md`
3. README and example guidance now state that a missing continue target is a stop condition, not a bootstrap signal.
   - Evidence: `README.md`, `examples/basic-workspace/AGENTS.md`
4. The full Campfire verifier suite passed with the new guardrail included.
   - Evidence: `./scripts/verify_repo.sh`

## Follow-up

The deferred automation-proposal backlog is still valid and should be resumed next, now that the resume semantics are safer across workspaces.
