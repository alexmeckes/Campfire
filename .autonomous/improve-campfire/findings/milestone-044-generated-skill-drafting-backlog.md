# Milestone 044 Generated Skill Drafting Backlog

## Why This Reframe Exists

The Pi-inspired queue is now complete:

- prompt templates exist and are verified
- steering versus follow-up guidance exists and is queryable
- generated skill discovery now has a packageable manifest
- session lineage can point evidence at a specific run branch

The next highest-leverage continuation is to make the generated-skill promotion path concrete by scaffolding draft skills directly from structured improvement candidates. Once that draft path exists, Campfire can verify it deterministically and then revisit the parked automation-proposal helper with better prompt and control-plane surfaces than it had before.

## Next Bounded Backlog

### milestone-044

Add a helper that drafts task-local or repo-local generated skills from structured improvement candidates.

Acceptance focus:

- a `skill_candidate` can materialize a draft `SKILL.md` and companion candidate metadata in the right scope
- the helper stays review-first and does not auto-promote anything to Campfire core
- discovery surfaces pick up the drafted skill after refresh

### milestone-045

Add deterministic verification and example coverage for generated-skill drafting.

Acceptance focus:

- verifier coverage proves draft generation, candidate linkage, and inventory refresh behavior
- example or temp-workspace coverage shows the drafted skill is visible in the standardized discovery manifest
- repo verification fails if the drafting path drifts

### milestone-046

Restore the deferred automation-proposal helper backlog on top of the stronger prompt, guidance, and skill-discovery surfaces.

Acceptance focus:

- Campfire can suggest automation proposals from current task state without duplicating prompt prose
- the proposal surface reuses the prompt-template and discovery/context layers instead of inventing another ad hoc output path
- the implementation remains local-first and optional

## Validation

- review this backlog note against the current generated-skill and improvement-backlog docs
- confirm the new queue remains single-agent, local-first, and dependency-safe
