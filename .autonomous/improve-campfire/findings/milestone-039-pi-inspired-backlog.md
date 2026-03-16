# Milestone 039 Pi-Inspired Backlog

## Why This Reframe Exists

Reviewing `badlogic/pi-mono/packages/coding-agent` surfaced a few useful ideas that map well to Campfire without importing Pi's full runtime model:

- first-class prompt templates for canonical operator flows
- a clearer distinction between interrupting guidance and follow-up guidance
- packageable repo-local and generated skills
- branchable session lineage for retries, course corrections, and benchmark repros

Those look higher leverage than the deferred automation-proposal helper backlog because they directly reduce prompt dependence and make the single-agent workflow easier to steer and improve over time.

The old automation-proposal backlog is deferred, not discarded. It can be reframed later if the new control-plane and prompt-template work still leaves that gap.

## Next Bounded Backlog

### milestone-039

Add a prompt-template layer for canonical Campfire operator flows.

Acceptance focus:

- canonical templates exist for resume, retrospective, benchmark, and improvement-promotion flows
- templates stay task-only and reusable instead of duplicating docs prose
- the implementation remains local-first and skill-compatible

### milestone-040

Add deterministic verification and example coverage for prompt templates.

Acceptance focus:

- verifier coverage proves template rendering and task-context selection
- example workspace guidance shows how templates are invoked
- repo verification fails if the template layer drifts

### milestone-041

Add a lightweight steering versus follow-up queue model for active tasks.

Acceptance focus:

- Campfire can record whether operator guidance should interrupt immediately or wait for the next safe boundary
- the state contract and generated context expose that distinction clearly
- the design stays single-agent and does not become a multi-agent scheduler

### milestone-042

Add packageable repo-local and generated skill discovery surfaces.

Acceptance focus:

- generated or repo-local skills can be discovered without custom one-off installer logic
- the surface stays compatible with the current lightweight skill model
- the generated-skill promotion path becomes more concrete

### milestone-043

Add session-lineage metadata for retries, branches, and benchmark repros.

Acceptance focus:

- task sessions can record parent-child lineage for retries or course-corrected runs
- benchmark and retrospective evidence can point at specific run branches
- the implementation stays local and queryable in the existing SQL control plane

## Validation

- review this backlog note against the current Campfire docs and self-hosted task state
- confirm the milestones are dependency-safe, local-first, and compatible with the single-agent model
