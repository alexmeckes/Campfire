# Progress Log

## 2026-03-14

- Task created.
- Objective: dogfood Campfire on itself and add the blocked-run lifecycle verifier
- Next slice: define the first milestone and validation target.

## 2026-03-14 milestone-001

- Changed: added repo-local AGENTS.md plus scripts/new_task.sh and scripts/resume_task.sh so Campfire can use its own long-horizon workflow.
- Changed: added skills/task-handoff-state/scripts/verify_blocked_retry.sh and wired it into scripts/verify_repo.sh and README.md.
- Validation: ran ./scripts/verify_repo.sh successfully after adding the blocked and retry verifier.
- Blockers: none.
- Next slice: choose the next Campfire improvement milestone.
