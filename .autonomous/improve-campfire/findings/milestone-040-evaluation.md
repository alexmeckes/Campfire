# Milestone 040 Evaluation

## Evaluated Milestone

- `milestone-040` - Add deterministic verification and example coverage for prompt templates

## Acceptance Criteria

### 1. A deterministic verifier covers task-bootstrap, resume, retrospective, benchmark, and improvement-promotion prompt rendering from stable Campfire state

Pass.

Evidence:

- Added `skills/task-handoff-state/scripts/verify_prompt_template_helper.sh`.
- Ran `./skills/task-handoff-state/scripts/verify_prompt_template_helper.sh` successfully.
- The verifier covers:
  - `task_bootstrap`
  - single-milestone `resume`
  - rolling bounded `resume`
  - `rolling_resume` for `until_stopped`
  - `retrospective`
  - `benchmark`
  - `improvement_promotion`

### 2. Example workspace coverage proves copied wrappers still surface prompt-template-backed output via the installed skill helper

Pass.

Evidence:

- Updated `examples/basic-workspace/scripts/verify_harness.sh` to copy and invoke `prompt_template_helper.sh` inside the temp workspace.
- Ran `./examples/basic-workspace/scripts/verify_harness.sh` successfully.

### 3. Repo verification includes prompt-template coverage so helper or reference drift breaks the suite

Pass.

Evidence:

- Updated `scripts/verify_repo.sh` to syntax-check the new wrappers, require the prompt template reference/data files, and run `verify_prompt_template_helper.sh`.
- Ran `./scripts/verify_repo.sh` successfully.

## Result

- `milestone-040` is validated.
- Rolling execution can auto-advance to `milestone-041`.
