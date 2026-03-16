# Campfire Generated Skills

## Purpose

This document defines how Campfire should handle generated micro-skills without turning the framework into an uncontrolled pile of auto-created prompts.

The goal is to let Campfire improve procedurally over time while keeping the workflow:

- reviewable
- benchmarkable
- easy to delete when a candidate is bad
- compatible with the existing skill architecture

This is an architecture document, not an automatic self-modification spec.

## Why Generated Skills Exist

Most repeated failures should not become new skills.

Campfire should prefer, in order:

1. verifier or benchmark updates
2. control-plane changes
3. repo-local lessons
4. generated skills

A generated skill is justified only when the recurring problem is primarily instructional:

- the agent needs a better diagnosis sequence
- the agent needs a better execution checklist
- the problem repeats across multiple tasks or runs
- a script cannot enforce the behavior cheaply

Generated skills are best thought of as procedural memory, not generic long-term memory.

## Non-Goals

- Do not auto-promote every retrospective note into a skill.
- Do not let generated skills bypass benchmarks or verifiers.
- Do not silently mutate Campfire core skills after one run.
- Do not replace repo rules, checklists, or scripts with skill sprawl.
- Do not create a hidden memory system that the operator cannot inspect.

## Terminology

### Skill Candidate

A structured proposal for a new or changed skill.

### Draft Skill

A generated skill artifact that is not yet trusted. It is only valid inside the scope where it was created.

### Promoted Skill

A draft skill that proved useful enough to become repo-local or Campfire-core.

## Decision Rules

Use a skill candidate only when all of these are true:

- the failure pattern is repeated or likely to repeat
- the best fix is a reusable procedure
- a new script or verifier would not solve the problem better
- the candidate can be described in a narrow scope
- the benefit can be validated with evidence

Do not create a skill candidate when:

- the issue is a one-off operator mistake
- the fix should be a lifecycle helper
- the fix should be a benchmark scenario
- the fix should be a verifier assertion
- the issue is only a repo-specific fact that belongs in `AGENTS.md`

## Candidate Schema

Campfire should treat the skill candidate as the unit of review.

Suggested shape:

```json
{
  "id": "skill-candidate-2026-03-15-start-slice-discipline",
  "source": {
    "type": "task_run",
    "task_slug": "build-the-playable-vertical-slice",
    "milestone_id": "m3_camp_and_save_loop",
    "run_id": "session-2026-03-15-1543"
  },
  "title": "Strengthen slice-start discipline before project edits",
  "problem": "Workers sometimes begin implementation before writing the active slice transition, which leaves the board and control plane stale during long runs.",
  "why_not_script": "The start transition is mechanical, but the recurring failure is broader: the worker also needs a fixed pre-edit checklist for validation target, active milestone, and expected proof.",
  "scope": "repo_local",
  "kind": "generated_micro_skill",
  "trigger_pattern": [
    "project file edits appear before slice_started",
    "task state remains validated while work is active"
  ],
  "evidence": [
    ".autonomous/build-the-playable-vertical-slice/checkpoints.json",
    ".autonomous/build-the-playable-vertical-slice/progress.md",
    "benchmarks/campfire-bench/scenarios/resume-after-interrupt.json"
  ],
  "proposed_skill": {
    "name": "slice-start-guard",
    "purpose": "Force a short pre-edit checklist for active slice state, validation target, and handoff synchronization.",
    "inputs": [
      "task context",
      "current milestone",
      "validation target"
    ],
    "outputs": [
      "deterministic slice start",
      "clear proof target",
      "consistent board visibility"
    ]
  },
  "promotion_state": "proposed",
  "confidence": "medium",
  "next_action": "Create a repo-local draft skill and benchmark whether it reduces stale-state runs."
}
```

Required fields:

- `id`
- `source`
- `title`
- `problem`
- `scope`
- `kind`
- `evidence`
- `promotion_state`
- `next_action`

Recommended fields:

- `why_not_script`
- `trigger_pattern`
- `proposed_skill`
- `confidence`

## Storage Model

Generated skills should exist in three scopes.

### 1. Task-Local Draft

Use for a fresh idea that came from one run.

Suggested path:

- `.autonomous/<task>/generated-skills/<skill-name>/SKILL.md`
- `.autonomous/<task>/generated-skills/<skill-name>/skill_candidate.json`

Use this scope when:

- the fix is still speculative
- the evidence comes from one task
- the skill may be thrown away after one experiment

### 2. Repo-Local Skill

Use when the pattern repeats within one project or project family.

Suggested path:

- `.campfire/generated-skills/<skill-name>/SKILL.md`
- `.campfire/generated-skills/<skill-name>/skill_candidate.json`

Use this scope when:

- at least two task runs support it
- the rule is useful for this repo
- it is not yet generic enough for Campfire core

### 3. Campfire-Core Candidate

Use when the pattern is reusable across projects and benchmarked.

Suggested path:

- `skills/generated/<skill-name>/SKILL.md`
- `skills/generated/<skill-name>/skill_candidate.json`

Use this scope only after promotion.

Campfire core should remain curated. Generated core candidates should still be reviewed before they are treated as durable defaults.

## Promotion States

Use a small explicit state machine:

- `proposed`
- `drafted`
- `trialing`
- `promoted_repo_local`
- `promoted_core`
- `rejected`
- `retired`

Meaning:

- `proposed`
  - candidate exists, no draft skill yet
- `drafted`
  - draft skill artifact exists
- `trialing`
  - it is being used in one or more controlled runs
- `promoted_repo_local`
  - accepted for one repo or workspace
- `promoted_core`
  - accepted into Campfire core
- `rejected`
  - not worth keeping
- `retired`
  - once useful, now superseded by a verifier, script, or core skill change

## Promotion Criteria

### Promote To Task-Local Draft

Use when:

- the candidate is well-scoped
- the issue is instructional
- there is enough evidence to test it

### Promote To Repo-Local

Require:

- repeated evidence from at least two runs or one run plus one benchmark scenario
- no simpler control-plane or verifier fix
- a short skill body with a narrow purpose
- proof that the draft reduced the target failure mode

### Promote To Campfire-Core

Require all of:

- reuse across at least two repos or benchmark families
- benchmark coverage or verifier coverage exists
- the skill stays narrow and composable
- the same behavior does not belong in an existing core skill instead
- the operator can explain why a new skill is better than a checklist addition

If those conditions are not met, keep it repo-local.

## Interaction With Existing Skills

Generated skills should not compete with the base stack.

Use them as adjuncts to:

- `task-framer`
- `course-corrector`
- `long-horizon-worker`
- `task-evaluator`
- `task-handoff-state`
- `task-retrospector`

The normal pattern should be:

1. `task-retrospector` identifies a reusable instructional gap.
2. It emits a `skill_candidate`.
3. A follow-up task drafts the micro-skill in task-local or repo-local scope.
4. Benchmarks or verifier runs check whether the candidate helps.
5. Only then should Campfire promote it.

## Relationship To Benchmarks And Verifiers

Generated skills should be downstream of evidence, not upstream of it.

A strong candidate should usually produce at least one of:

- a benchmark scenario
- a verifier update
- a measurable reduction in orchestration overhead

If a candidate cannot be tested, it should not be promoted.

## Good Candidate Examples

Good generated micro-skills:

- "Before Godot runtime validation, normalize typed locals and load the smallest headless validator first."
- "For resume-after-interrupt scenarios, force a pre-edit review of `task_context.json`, active validator ID, and current stop reason."
- "When a rolling queue is nearly empty, use a fixed reframe checklist before creating new milestones."

Bad generated micro-skills:

- "Be more careful"
- "Remember the project better"
- "Always read everything"
- "Handle blockers better"

If the idea sounds like advice instead of a procedure, it is probably not a good skill.

## Minimal Output From `task-retrospector`

When retrospection identifies a skill-worthy issue, it should write:

- a short retrospective note
- a `skill_candidate.json`
- optionally a draft `SKILL.md` only if the next action is already approved

Default behavior should stop at candidate creation, not automatic promotion.

## Suggested Future Control-Plane Support

Later Campfire versions can add:

- `skill_candidates` table in `campfire.db`
- `campfire improvement promote`
- `campfire generated-skill draft`
- benchmark linkage from candidate ID to benchmark scenario IDs

Campfire does not need those commands yet to adopt the policy.

## Recommended First Policy

If Campfire implements generated skills gradually, start with this rule:

- allow task-local and repo-local draft skills
- require explicit review for core promotion
- require benchmark or verifier support before promotion
- retire skills aggressively when a script or verifier makes them unnecessary

That keeps the framework lightweight while still letting it learn procedurally over time.
