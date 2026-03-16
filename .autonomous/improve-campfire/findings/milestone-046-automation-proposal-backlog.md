# Milestone 046 Automation Proposal Backlog

## Why This Reframe Exists

The generated-skill helper loop is now complete:

- draft skills can be created mechanically from structured candidates
- deterministic verifier coverage protects the draft path
- example wrapper coverage proves the drafted skill shows up in the standardized inventory surfaces

Retrospective signal from the completed helper work:

- new operator helpers should not stop at a manual smoke test
- the backlog should reserve deterministic verifier and wrapper-surface coverage immediately after the helper lands

With prompt templates, task guidance, discovery manifests, and generated context already in place, the deferred automation-proposal helper can now reuse those stronger surfaces instead of inventing another prompt or state format.

## Next Bounded Backlog

### milestone-046

Add an automation proposal helper that emits schedule-agnostic proposal metadata from current Campfire task state.

Acceptance focus:

- the helper suggests a stable proposal name and task-only prompt for each supported proposal variant
- prompt bodies come from `prompt_template_helper.sh` instead of duplicated inline prose
- proposal metadata is derived from the existing task context and local workspace, not a new ad hoc state file

### milestone-047

Add deterministic verification and example coverage for automation proposals.

Acceptance focus:

- verifier coverage proves proposal naming, prompt selection, and variant defaults
- example coverage proves wrapper usage against a temp workspace
- repo verification fails if the automation proposal helper or wrapper surface drifts

### milestone-048

Document automation proposal helper usage in README and example guidance.

Acceptance focus:

- README and the task-state skill explain when to use proposal metadata versus prompt-only helper output
- example guidance points operators at the local wrapper flow instead of copying prompts by hand
- the documentation stays schedule-agnostic and local-first

### milestone-049

Surface automation proposal guidance from `resume_task.sh` for rolling tasks.

Acceptance focus:

- rolling resume output exposes the proposal helper as an optional next step next to the prompt-only variants
- resume output stays compatible with existing rolling guidance and does not invent schedule defaults
- the new guidance reuses the proposal helper instead of duplicating its output logic

### milestone-050

Add deterministic verification that `resume_task.sh` surfaces automation proposal guidance correctly.

Acceptance focus:

- verifier coverage proves rolling resume output includes the proposal helper guidance when appropriate
- the coverage remains local-first and does not depend on external automation state
- repo verification fails if the resume guidance drifts

## Validation

- review this backlog note against the current prompt-template, guidance, generated-skill, and resume-task surfaces
- confirm the restored queue remains single-agent, local-first, and dependency-safe
