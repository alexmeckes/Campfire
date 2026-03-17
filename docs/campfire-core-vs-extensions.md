# Campfire Core vs Extensions

## Purpose

Campfire should stay small.

This note defines the boundary between the core harness and optional extensions so new ideas do not silently become permanent framework complexity.

## Core

The minimum surface is the baseline promise:

- a single agent can resume from disk
- start a bounded slice
- do work
- validate it
- record state
- stop cleanly on completion, blocker, or decision boundary

Campfire's current shared core is a little larger than that minimum because the shipped scripts and verifiers already rely on a few supporting surfaces.

Core currently includes:

- task state and task directories under the configured task root (default: `.autonomous/<task>/`)
- slice lifecycle helpers such as `start_slice.sh` and `complete_slice.sh`
- structured runtime state in `.campfire/campfire.db`
- generated task and project context
- durable handoff and resume surfaces
- explicit validation and doctor checks
- minimal board visibility for active, queued, blocked, and done work
- prompt-template rendering used by shared helpers
- operator guidance persistence
- session lineage metadata
- skill inventory and generated context projections

The rule from here forward is about growth: if a new feature is not required shared infrastructure for that loop, it should not be added to core by default.

## Extensions

Extensions are optional layers built on top of core state.

They may be useful, but Campfire should still function without them.

Examples:

- automation proposal helpers
- benchmark adapters or scenario packs
- generated-skill drafting and promotion flows
- repo-specific wrappers
- Codex App-specific integrations
- alternate board views

These should be implemented so they can be ignored, removed, or replaced without breaking the basic Campfire loop.

## Decision Rule

A feature belongs in core only if at least one of these is true:

- removing it would break resume, execution, validation, or clean stop behavior
- it eliminates a repeated manual step for nearly every Campfire task
- multiple extensions already depend on it as shared infrastructure
- shipped core helpers or verifiers already rely on it as common infrastructure

Otherwise it should start as an extension.

## Preferred Order

When adding capability, prefer this order:

1. improve an existing helper or verifier
2. add a repo-local wrapper or extension
3. promote shared infrastructure into core only if repeated evidence justifies it

That keeps Campfire from turning into a general orchestration framework.

## Non-Goals

- Do not turn core into a plugin host for every experiment.
- Do not add product-specific automation logic to core without a strong reason.
- Do not add new top-level primitives when an existing state surface can carry the behavior.
- Do not make the single-agent loop depend on optional integrations.

## Practical Test

Before adding a new core feature, ask:

- Can this live as a helper or wrapper instead?
- Can this be an extension that reads the existing control plane?
- Would a verifier or benchmark catch the same problem more cheaply?
- If this were deleted in six months, would Campfire still do its basic job?

If the answer to the last question is yes, it probably does not belong in core.
