# milestone-029 missing resume course correction

- The automation-proposal backlog was useful, but the fresh-thread test exposed a more urgent flaw: a missing continue target in the wrong workspace could still be reframed into a brand-new task.
- That behavior violates the intended resume semantics for Campfire. A continue or resume request against a named `.autonomous/<task>/` should stop on missing state, not bootstrap a replacement task.

## Decision

- Defer the automation-proposal backlog.
- Use the current backlog to add a missing-resume guardrail in task-state tooling and skill guidance.
- Requeue the automation-proposal backlog after the guardrail is validated.
