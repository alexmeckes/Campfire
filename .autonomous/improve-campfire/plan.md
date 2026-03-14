# improve-campfire

## Objective

dogfood Campfire on itself and add the blocked-run lifecycle verifier

## Source Docs

- README.md
- AGENTS.md
- skills/long-horizon-worker/SKILL.md
- skills/task-handoff-state/SKILL.md
- skills/task-handoff-state/references/task-state-contract.md

## Milestones

- [x] Make the Campfire repo self-hosting with AGENTS.md and local task wrappers
- [x] Add the blocked and retry lifecycle verifier
- [x] Validate the repo with verify_repo.sh
- [x] Add task framing and course-correction skills
- [ ] Choose the next Campfire improvement milestone

## Notes

- Created: 2026-03-14
- Campfire should be able to improve itself using the same task-state contract it publishes
