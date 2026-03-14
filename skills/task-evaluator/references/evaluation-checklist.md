# Evaluation Checklist

Use this checklist when evaluating a Campfire milestone.

## Inputs

- `checkpoints.json` current milestone and acceptance criteria
- latest `progress.md` entries
- relevant files or diffs
- validation commands and outputs
- `artifacts.json` plus any files it names

## Questions

1. What is the milestone being evaluated?
2. Which acceptance criteria are explicitly listed?
3. What concrete evidence exists for each criterion?
4. Was the strongest practical validation used?
5. Is there any missing proof, missing implementation, or silent assumption?
6. Should the task be marked `validated`, kept `ready`, marked `blocked`, or sent to `$course-corrector`?

## Evaluation Outcomes

### Validate

Use when every acceptance criterion is supported by evidence.

- `status`: `validated`
- `phase`: `verification`
- `last_run.stop_reason`: `milestone_validated`
- write an evaluation note under `findings/`

### Continue

Use when the milestone is close but not fully proven.

- keep `status` as `ready` or `in_progress`
- record the missing proof or missing implementation
- set one narrow next slice

### Course Correct

Use when the milestone or sequence is wrong.

- preserve task history
- update the plan with `$course-corrector`
- record why the old path is no longer right

### Block

Use when the missing piece cannot be resolved safely in the current run.

- set blocker metadata in `checkpoints.json`
- record the exact missing dependency or decision
