# Framing Checklist

Use this checklist when turning a vague objective into a real Campfire task.

## Inputs

- `AGENTS.md`
- repo layout
- source-of-truth docs
- user objective
- existing `.autonomous/<task>/` files, if any

## Outputs To Update

- `plan.md`
- `runbook.md`
- `handoff.md`
- `checkpoints.json`
- `artifacts.json` when expected outputs are already known

## Required Framing Decisions

### Objective

- Rewrite the objective into one stable sentence.
- Remove vague verbs when possible.

### Source Docs

- List the project rules and product docs that define correctness.
- Put them in priority order if there is a clear winner.

### Milestones

- Give each milestone a stable ID.
- Prefer 3 to 5 milestones for the first framing pass.
- Each milestone should have a clear done condition.

### Acceptance Criteria

- Use concrete checks, files, commands, or runtime evidence.
- Avoid purely subjective criteria unless the project is design-heavy.

### Runbook

- Fill setup commands when known.
- Fill validation commands when known.
- If unknown, write what still needs discovery.

### First Slice

- Choose one dependency-safe slice that can be executed immediately.
- Write it into both `handoff.md` and `checkpoints.json`.

## Risks To Surface

- missing environment or credentials
- missing source docs
- unclear success criteria
- likely blockers from external dependencies
- unresolved project decisions
