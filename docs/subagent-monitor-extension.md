# Subagent Monitor Extension

## Purpose

If Campfire ever uses subagents, the safest first form is a monitoring extension, not a worker swarm.

This note defines a narrow subagent model that helps a primary Campfire run stay healthy without changing the core single-agent ownership model.

The subagent should:

- observe long-running progress
- detect likely stalls or drift
- surface bounded nudges or escalation signals

It should not:

- own the main task
- edit shared task state directly
- independently advance milestones
- become a scheduler or merge manager

## Why This Form First

Campfire’s core claim is still:

- one agent can resume from disk
- activate a slice
- work
- validate
- stop cleanly

A monitoring subagent can improve that loop without redefining it.

That is safer than jumping directly to:

- multi-agent implementation
- task splitting and merging
- parallel milestone ownership
- durable multi-agent orchestration

## Model

The primary agent remains the only owner of:

- the active task
- the active slice
- milestone completion
- validation decisions
- durable task-state writes

The monitoring subagent is a sidecar observer.

Its job is to read the same control plane and answer:

- Is the run still making meaningful progress?
- Is task state drifting from behavior?
- Has the run likely hit a blocker, loop, or decision boundary?
- Should the primary agent pause, re-evaluate, or stop?

## Inputs

The monitoring subagent should read only existing Campfire surfaces:

- `.campfire/registry.json`
- `.campfire/project_context.json`
- `<task-root>/<task>/task_context.json`
- `checkpoints.json`
- `progress.md`
- `handoff.md`
- recent validation or artifact summaries when needed

Optional adapter-specific inputs:

- Claude hook/event data
- Codex session metadata
- benchmark result files

It should not require any new core database tables.

## Outputs

The monitoring subagent should emit only bounded outputs.

Good outputs:

- a short advisory note
- a suggested `queue_guidance.sh` action
- a suggestion to run `doctor_task.sh`
- a suggestion to stop on a decision boundary
- a suggestion to record a retrospective candidate

Optional machine-readable output:

- `.campfire/monitoring/alerts/<timestamp>-<task>.json`

Example alert shape:

```json
{
  "task_slug": "improve-campfire",
  "severity": "medium",
  "category": "stalled_progress",
  "summary": "No slice or milestone movement detected across repeated heartbeat refreshes.",
  "recommended_action": "pause_and_reassess",
  "suggested_helper": "./scripts/doctor_task.sh improve-campfire"
}
```

The primary agent or operator decides what to do next.

## Safe Triggers

This extension is most useful when triggered by:

- long wall-clock runtime with no milestone or slice movement
- repeated heartbeat updates with unchanged task state
- repeated verifier failures
- repeated restart/resume loops
- `waiting_on_decision` reached but work continues
- queue exhaustion without reframe

It may also run on a timer during long unattended sessions, but only as an observer.

## Recommended Actions

A monitoring subagent should recommend only a small set of actions:

1. `allow`
   - work appears healthy
2. `nudge`
   - suggest `resume_task.sh` or current-slice review
3. `doctor`
   - suggest `doctor_task.sh`
4. `guidance`
   - suggest `queue_guidance.sh --mode next_boundary ...`
5. `pause`
   - likely blocker, drift, or decision boundary
6. `retro`
   - repeated issue should become an improvement candidate

That keeps the result space small and reviewable.

## Guardrails

The monitoring subagent must not:

- modify `checkpoints.json`
- modify `.campfire/campfire.db`
- run `complete_slice.sh`
- declare validation complete
- create or reframe milestones on its own

If it writes anything at all, it should write only extension-local alert artifacts.

The only safe “write into Campfire” path should be indirect:

- recommend a helper
- primary agent or operator chooses to run it

## Where It Lives

This should remain an extension.

Possible homes:

- a repo-local script wrapper
- a Codex-side adapter helper
- a Claude Code adapter hook/sidecar
- a benchmark harness side observer

It should not add new Campfire core primitives.

## Initial Implementation Shape

If this gets built, the smallest useful version is:

1. `monitor_task.sh <task-slug>`
   - reads task/project/registry context
   - emits a short advisory plus exit code
2. one verifier
   - proves stall detection and decision-boundary detection
3. optional adapter integration
   - Claude/Codex can call it during long runs

That is enough to learn whether the idea is helpful before designing anything more ambitious.

## Benchmark Value

This extension should be benchmark-backed before it grows.

Useful CampfireBench scenarios:

- long run with no milestone movement
- looping verifier failures
- stale heartbeat with unchanged task context
- ignored `waiting_on_decision`

The benchmark question is:

- does a monitoring subagent reduce wasted wall-clock time or bad continuation decisions without adding too much orchestration overhead?

If the answer is no, the extension should stay small or be dropped.

## Relationship To Future Subagents

If Campfire ever explores stronger delegation later, this monitor model is still useful as the first layer.

It helps answer:

- where single-agent runs actually stall
- what signals matter
- whether subagent help is really needed

That is a better path than starting with “multiple workers” before the failure modes are clear.
