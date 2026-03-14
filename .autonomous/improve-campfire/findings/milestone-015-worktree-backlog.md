# milestone-015 worktree backlog

The next Campfire backlog should focus on optional worktree-aware bootstrapping for git repos.

This fits the repo priorities:

- stronger long-horizon isolation for risky or long-lived work
- better portability for git-backed projects
- explicit verification instead of an undocumented manual pattern

## Proposed backlog

1. `milestone-015` - add a worktree-aware task bootstrap helper for git repos
2. `milestone-016` - add deterministic verification for worktree bootstrap and safe non-git fallback behavior
3. `milestone-017` - document worktree-aware bootstrapping in README and example guidance

## Acceptance criteria

- Campfire can create a dedicated worktree-backed task bootstrap path for git repos without breaking non-git workspaces
- the repo verifier covers the worktree bootstrap flow deterministically
- README and self-hosted task state describe when to use worktree-backed setup versus in-place setup
