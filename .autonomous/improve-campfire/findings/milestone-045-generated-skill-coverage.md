# Milestone 045 Generated Skill Coverage

## Goal

Add deterministic verification and example coverage for the generated-skill drafting helper so drift breaks the repo suite instead of hiding behind manual smoke checks.

## Acceptance Focus

- deterministic verifier coverage proves draft generation, candidate linkage, and inventory refresh behavior
- example workspace wrappers can invoke the draft helper and surface the drafted skill through the standardized inventory
- repo verification fails if the generated-skill drafting path or wrapper surface drifts

## Next Slice

- add a dedicated verifier for repo-local and task-local draft generation
- add an example wrapper for the draft helper and exercise it in `examples/basic-workspace/scripts/verify_harness.sh`
- wire the verifier into `scripts/verify_repo.sh`

## Validation Target

- `./skills/task-handoff-state/scripts/verify_draft_generated_skill.sh`
- `CAMPFIRE_SKILLS_ROOT=/Users/alexmeckes/Downloads/Campfire/skills ./examples/basic-workspace/scripts/verify_harness.sh`
- `./scripts/verify_repo.sh`
