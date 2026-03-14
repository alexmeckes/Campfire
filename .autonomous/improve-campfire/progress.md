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
