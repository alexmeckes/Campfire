# milestone-017 evaluation

- Result: validated

## Acceptance criteria

1. Campfire provides an optional worktree-backed bootstrap path for git repos.
   - Evidence: `skills/task-handoff-state/scripts/bootstrap_task.sh`
   - Evidence: `scripts/new_task.sh`

2. The repo verifier covers both git worktree bootstrap and deterministic non-git fallback behavior.
   - Evidence: `skills/task-handoff-state/scripts/verify_worktree_bootstrap.sh`
   - Evidence: `./skills/task-handoff-state/scripts/verify_worktree_bootstrap.sh`
   - Evidence: `./scripts/verify_repo.sh`

3. README, skill guidance, and example guidance explain when to use worktree-backed setup.
   - Evidence: `README.md`
   - Evidence: `skills/task-handoff-state/SKILL.md`
   - Evidence: `examples/basic-workspace/AGENTS.md`

## Validation summary

- `./skills/task-handoff-state/scripts/verify_worktree_bootstrap.sh` passed.
- `./scripts/verify_repo.sh` passed with the worktree bootstrap verifier included.
