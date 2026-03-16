# Milestone 042 Skill Discovery Surfaces

## Goal

Add a small, packageable discovery surface for Campfire core skills, repo-local generated skills, and task-local generated skills without inventing custom installer logic for each scope.

## Acceptance Focus

- generated or repo-local skills can be discovered through one standardized manifest or context surface
- the surface stays compatible with the current lightweight skill model and does not require a daemon or server
- the generated-skill promotion path becomes more concrete because draft and repo-local skill locations are queryable

## Next Slice

- render a repo-local skill inventory that indexes core, repo-local generated, and task-local generated skill directories
- expose the inventory through generated context and a small helper surface instead of ad hoc path guessing
- add deterministic verification that discovery works for repo-local and task-local generated skills in a temp workspace

## Validation Target

- targeted skill-inventory checks in the control-plane helpers
- a deterministic verifier for generated-skill discovery
- `./scripts/verify_repo.sh`
