# Subagent Monitor Extension

## Purpose

If Campfire uses subagents, the safest first form is a monitoring extension, not a worker swarm.

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

## Codex Default Pattern

For rolling Codex App runs, the default Campfire pattern should be exactly one continuous monitor sidecar per active task.

That means:

- the primary agent starts or resumes the task
- the primary agent spawns one monitor sidecar subagent for that task
- the sidecar runs `./scripts/monitor_task_loop.sh <task-slug>` or the skill-path equivalent
- the sidecar stays alive across slice boundaries until the parent run stops
- the sidecar remains observer-only and writes only `.campfire/monitoring/` artifacts

This is intentionally not a general orchestration layer:

- no worker swarm
- no milestone splitting
- no durable state ownership transfer
- no scheduler semantics in Campfire core

If a monitor sidecar already exists for the same task in the current Codex run, reuse it instead of spawning duplicates.

## Allowed vs Forbidden

Campfire should allow only bounded delegation patterns.

Allowed:

- a monitoring sidecar that reads task state and emits advisories
- an explorer sidecar that answers a narrow repo or code question
- a bounded worker sidecar with a clearly assigned write scope
- parent-directed polling or waiting for a sidecar result
- extension-local artifacts such as notes, alerts, or patch outputs

Forbidden:

- milestone ownership by more than one agent
- subagents editing `checkpoints.json`, `handoff.md`, or `progress.md` directly
- subagents calling `complete_slice.sh`, `enable_rolling_mode.sh`, or queue-reframe helpers on their own
- automatic fan-out of multiple workers without explicit parent intent
- background queues, leases, retries, or scheduler semantics in Campfire core
- any design where the primary agent is no longer the single writer of durable task state

The rule is simple:

- the parent owns state
- the sidecar produces information or a bounded patch
- the parent decides whether to integrate it

## Single-Writer Rule

The single-writer rule is the main guardrail for subagents.

Only the primary agent may:

- activate a slice
- complete a slice
- mark validation complete
- change task status
- reframe the queued backlog
- record the final stop reason

Subagents may:

- read task state
- inspect code or artifacts
- prepare a patch inside an assigned scope
- prepare a recommendation for the parent agent

If a subagent needs something outside its scope, it should return control to the parent rather than widening its role.

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

The same boundary should hold for any future explorer or bounded worker sidecars:

- write locally inside the assigned scope if needed
- never write Campfire durable state directly
- never become the authority on milestone or task completion

## Where It Lives

This should remain an extension.

Possible homes:

- a repo-local script wrapper
- a Codex-side adapter helper
- a Claude Code adapter hook/sidecar
- a benchmark harness side observer

It should not add new Campfire core primitives.

## Initial Implementation Shape

The smallest useful version is:

1. `monitor_task.sh <task-slug>`
   - reads task/project/registry context
   - emits a short advisory plus exit code
2. `monitor_task_loop.sh <task-slug>`
   - repeatedly calls `monitor_task.sh`
   - writes latest and state snapshots under `.campfire/monitoring/`
   - emits alert files only when the state changes into a non-allow action
3. one verifier
   - proves stall detection, decision-boundary detection, and alert emission
4. optional adapter integration
   - Codex rolling prompts should tell the parent agent to spawn exactly one continuous monitor sidecar
   - Claude/Codex may still call the one-shot monitor helper during long runs

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

## Smallest Useful Delegation Contract

If Campfire adds non-monitor sidecars later, the contract should still stay narrow:

1. The parent agent explicitly chooses the sidecar role.
2. The sidecar gets one bounded goal and, if applicable, one bounded write scope.
3. The sidecar returns one of:
   - advisory
   - answer
   - patch/result
   - blocker
4. The parent agent decides whether to adopt the result and is solely responsible for durable task-state updates.

If any proposal requires a persistent scheduler, multi-agent milestone ownership, or shared durable state writes, it has crossed the line from delegation into orchestration and should not enter Campfire core.
