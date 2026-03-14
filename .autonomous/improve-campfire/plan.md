# improve-campfire

## Objective

dogfood Campfire on itself and harden lifecycle verification coverage

## Source Docs

- README.md
- AGENTS.md
- skills/task-framer/SKILL.md
- skills/course-corrector/SKILL.md
- skills/long-horizon-worker/SKILL.md
- skills/task-evaluator/SKILL.md
- skills/task-handoff-state/SKILL.md
- skills/task-handoff-state/references/task-state-contract.md

## Milestones

- [x] Make the Campfire repo self-hosting with AGENTS.md and local task wrappers
- [x] Add the blocked and retry lifecycle verifier
- [x] Validate the repo with verify_repo.sh
- [x] Add task framing and course-correction skills
- [x] Add the course-correction lifecycle verifier
- [x] Add a task-evaluator skill and evaluator-focused verification coverage
- [ ] Choose the next Campfire improvement milestone

## Notes

- Created: 2026-03-14
- Campfire should be able to improve itself using the same task-state contract it publishes
- Milestone-004 is the current unattended-run target and should end with repo verification
