# Retrospective Checklist

Use this checklist when turning a Campfire run into reusable improvements.

For the generated micro-skill policy, promotion states, and candidate schema, see [Campfire generated skills](/Users/alexmeckes/Downloads/Campfire/docs/campfire-generated-skills.md).
Use [record_improvement_candidate.sh](/Users/alexmeckes/Downloads/Campfire/skills/task-handoff-state/scripts/record_improvement_candidate.sh) when the retrospective should land in the SQL improvement backlog instead of staying prose-only.

## Inputs

- `checkpoints.json`
- `handoff.md`
- `progress.md`
- `artifacts.json`
- relevant `findings/`
- benchmark scenario or result files when applicable

## Questions

1. What was the real outcome of the run?
2. What friction, drift, or waste showed up?
3. Was the issue repeated or likely to recur?
4. What Campfire surface should absorb the fix?
5. Is the best next step a benchmark, verifier, skill update, control-plane update, or repo-local lesson?

## Outcome Types

### Benchmark Candidate

Use when the failure mode should be measured repeatedly.

Examples:

- resume drift
- queue replenishment regressions
- false validation
- state drift between files and SQL

### Verifier Candidate

Use when Campfire should catch the issue automatically before a human notices it.

Examples:

- missing lifecycle transition
- stale registry behavior
- context projection drift

### Skill Candidate

Use when the instructions are too weak or ambiguous.

Examples:

- worker forgets to start a slice
- evaluator validates weak evidence
- framer produces under-sized backlogs repeatedly

Promotion rule:

- start as a task-local or repo-local candidate first
- require benchmark or verifier support before core promotion
- prefer verifier or control-plane fixes when they solve the same problem better

### Control-Plane Candidate

Use when the fix should become a script, DB field, registry field, or generated context improvement.

Examples:

- add a lifecycle helper
- add a registry field
- add a SQL-backed status transition

### Repo Lesson

Use when the lesson is mostly local to one consumer repo and should not change Campfire core.

## Good Retrospectives

Keep them short and explicit:

- one sentence for what happened
- one sentence for why it matters
- one line naming the exact follow-up category
- one line naming the next concrete action

If the lesson is reusable, mirror it into a structured improvement candidate so it can be promoted into a real follow-up task later.
