# Milestone 044 Evaluation

## Evaluated Milestone

- `milestone-044` - Add a helper that drafts generated skills from structured improvement candidates

## Acceptance Criteria

### 1. A `skill_candidate` can materialize a draft `SKILL.md` and companion candidate metadata in task-local or repo-local scope

Pass.

Evidence:

- Added `skills/task-handoff-state/scripts/draft_generated_skill.sh` plus the repo-local wrapper `scripts/draft_generated_skill.sh`.
- Ran a temp-workspace draft flow that recorded a `skill_candidate`, drafted a repo-local generated skill, and confirmed both `SKILL.md` and `skill_candidate.json` were written.

### 2. The draft helper stays review-first and does not auto-promote anything to Campfire core

Pass.

Evidence:

- The helper only writes task-local or repo-local generated skill directories.
- It marks the existing candidate as `drafted`; it does not create a core skill or mutate Campfire core directories.
- The generated skill scaffold itself is labeled as a draft for review before wider reuse.

### 3. Discovery surfaces pick up the drafted skill after refresh

Pass.

Evidence:

- The temp-workspace draft flow refreshed the registry and confirmed the drafted skill appeared in `.campfire/skill_inventory.json` with scope `repo_local_generated`.
- The drafted entry carried a stable `package_name`, proving it is visible through the standardized discovery surface rather than custom path guessing.

## Result

- `milestone-044` is validated.
- Rolling execution can auto-advance to `milestone-045`.
