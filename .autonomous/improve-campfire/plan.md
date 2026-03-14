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
- [x] Add rolling execution policy and auto-advance verification coverage
- [x] Add a helper script for switching an existing task into rolling mode
- [x] Add a dedicated rolling-task example under `examples/basic-workspace/`
- [x] Document Codex App launch patterns for live-thread and background-task rolling runs
- [x] Add rolling budget-limit verification coverage
- [x] Add rolling waiting-on-decision verification coverage
- [x] Document rolling stop-condition behavior for Codex App runs
- [x] Add dynamic rolling queue-replenishment policy and helper defaults
- [x] Add rolling reframe verification coverage
- [x] Document dynamic rolling queue replenishment for Codex App runs
- [ ] Choose the next Campfire improvement milestone

## Notes

- Created: 2026-03-14
- Campfire should be able to improve itself using the same task-state contract it publishes
- Milestone-005 adds rolling execution policy for Codex App runs that should keep going while the user is away
- Milestones 006 through 008 were completed in one rolling run, so the current backlog is exhausted
- The next rolling backlog focuses on stop conditions other than success so unattended Codex App runs can pause and resume predictably
- Milestones 009 through 011 were completed in one rolling run, so the next unattended session should frame a fresh backlog before continuing
- Milestones 012 through 014 make rolling mode self-replenishing so the next unattended session can keep going when queue depth gets low and budget remains
