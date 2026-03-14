# Milestone-024 Until-Stopped Mode

## Why

The autonomy floor made runs longer, but Campfire still treated rolling execution as bounded. The remaining internal stop causes were the runtime budget, milestone cap, and reframe cap.

## Decision

Add an explicit `run_style: until_stopped` execution mode for rolling tasks.

That mode should:

- remove the internal runtime budget
- remove internal milestone and reframe caps
- keep queue replenishment active
- reserve `manual_pause` for explicit user or external interruption
- stop only on `blocked`, `waiting_on_decision`, or safe-work exhaustion after permitted reframes

## Expected Effect

Codex App runs can keep advancing through queued work and bounded replans until the user manually stops them or the task reaches a real boundary.
