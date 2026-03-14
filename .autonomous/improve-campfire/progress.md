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

## 2026-03-14 milestone-002

- Changed: added the generic task-framing and course-correction skills so Campfire now covers task formation, execution, state, and re-planning.
- Changed: wired the new skills into install_skills.sh, verify_repo.sh, README.md, and AGENTS.md.
- Validation: ran ./scripts/verify_repo.sh successfully after adding the new skills and installer wiring.
- Blockers: none.
- Next slice: choose the next Campfire improvement milestone.

## 2026-03-14 milestone-003

- Changed: added skills/task-handoff-state/scripts/verify_course_correction.sh to simulate a real re-plan and prove the corrected milestone becomes the resume target.
- Changed: updated verify_repo.sh, README.md, and the task-state contract to treat `course_corrected` as a first-class stop reason.
- Validation: ran ./skills/task-handoff-state/scripts/verify_course_correction.sh and ./scripts/verify_repo.sh successfully.
- Blockers: none.
- Next slice: choose the next Campfire improvement milestone.

## 2026-03-14 milestone-004 framing

- Changed: framed the next unattended Campfire milestone as `task-evaluator skill and evaluator-focused verification coverage`.
- Changed: added a milestone brief with bounded planning and execution slices for a roughly two-hour run.
- Validation: updated plan.md, runbook.md, handoff.md, checkpoints.json, and artifacts.json to point at milestone-004.
- Blockers: none.
- Next slice: spend one bounded slice framing the evaluator scope, then implement the skill, wire it into the repo, and validate with verify_repo.sh.

## 2026-03-14 milestone-004

- Changed: added the generic `task-evaluator` skill with agent metadata and an evaluation checklist reference.
- Changed: added `skills/task-handoff-state/scripts/verify_task_evaluation.sh` to simulate an independent milestone evaluation and validated handoff.
- Changed: wired the evaluator into install_skills.sh, verify_repo.sh, README.md, AGENTS.md, and the task-state docs.
- Validation: ran ./skills/task-handoff-state/scripts/verify_task_evaluation.sh and ./scripts/verify_repo.sh successfully.
- Blockers: none.
- Next slice: choose the next Campfire improvement milestone.

## 2026-03-14 milestone-005

- Changed: added rolling execution policy to the task-state contract and checkpoint normalization so Campfire can distinguish single-milestone runs from rolling Codex App runs.
- Changed: updated the framing, execution, course-correction, and evaluation skills to honor rolling auto-advance semantics.
- Changed: added `skills/task-handoff-state/scripts/verify_rolling_execution.sh` and wired it into the repo verifier.
- Changed: updated the repo-local task wrappers to prefer the repo skill copies over stale global installs, then refreshed the global skill install with `./scripts/install_skills.sh`.
- Validation: ran ./skills/task-handoff-state/scripts/verify_rolling_execution.sh, ./scripts/verify_repo.sh, and ./scripts/resume_task.sh improve-campfire successfully.
- Blockers: none.
- Next slice: start milestone-006 and keep moving through the rolling backlog until a real stop condition appears.
