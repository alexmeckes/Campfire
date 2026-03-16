# Milestone 040 Prompt Template Coverage

## Goal

Turn the new prompt-template layer into a deterministic Campfire surface that is covered by verifiers and visible in the example workspace flow.

## Acceptance Focus

- A dedicated verifier proves the shared prompt-template helper renders the expected task-bootstrap, resume, retrospective, benchmark, and improvement-promotion prompts from stable task state.
- Example workspace coverage keeps working when the example wrappers are copied into a temp workspace and rely on the installed skill helper rather than repo-only paths.
- `scripts/verify_repo.sh` fails if the prompt-template helper, reference doc, or example integration drifts.

## Next Slice

- Add `verify_prompt_template_helper.sh`.
- Wire the verifier into `scripts/verify_repo.sh`.
- Tighten example or README references only where the coverage exposes drift.

## Validation Target

- `./skills/task-handoff-state/scripts/verify_prompt_template_helper.sh`
- `./examples/basic-workspace/scripts/verify_harness.sh`
- `./scripts/verify_repo.sh`
