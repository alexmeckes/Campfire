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
- [x] Add a worktree-aware task bootstrap helper for git repos
- [x] Add deterministic verification for worktree bootstrap and non-git fallback behavior
- [x] Document worktree-aware bootstrapping in README and example guidance
- [x] Add a reusable automation-pattern reference for recurring Codex App runs
- [x] Add deterministic verification or example coverage for automation-ready prompts and workspace guidance
- [x] Document recurring automation patterns in README and example guidance
- [x] Enforce autonomous rolling floors and external-only manual pause semantics
- [x] Add deterministic verification for autonomous rolling floor defaults
- [x] Document autonomous rolling floor behavior in README and example guidance
- [ ] Add an automation prompt helper that emits task-only recurring prompt variants from Campfire state
- [ ] Add deterministic verification for automation prompt helper variants and task-state selection
- [ ] Document automation prompt helper usage in README and example guidance
- [ ] Expose automation prompt helper guidance from `resume_task.sh` for rolling tasks
- [ ] Add deterministic verification that `resume_task.sh` surfaces automation-helper guidance correctly

## Notes

- Created: 2026-03-14
- Campfire should be able to improve itself using the same task-state contract it publishes
- Milestone-005 adds rolling execution policy for Codex App runs that should keep going while the user is away
- Milestones 006 through 008 were completed in one rolling run, so the current backlog is exhausted
- The next rolling backlog focuses on stop conditions other than success so unattended Codex App runs can pause and resume predictably
- Milestones 009 through 011 were completed in one rolling run, so the next unattended session should frame a fresh backlog before continuing
- Milestones 012 through 014 make rolling mode self-replenishing so the next unattended session can keep going when queue depth gets low and budget remains
- The next backlog focuses on optional worktree-aware bootstrapping so git-backed long runs can isolate risky work without weakening non-git portability
- Milestones 015 through 017 were completed in one rolling run, so the next bounded reframe focuses on recurring automation patterns for Codex App tasks
- Milestones 018 through 020 were completed in one rolling run, but the next priority became the autonomy floor because the user still experienced five-minute bursts instead of a real unattended loop
- Milestones 021 through 023 strengthened the autonomous rolling floor, so the deferred automation-helper backlog now starts at milestone-024 with a deeper queue
