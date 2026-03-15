# Example Workspace

This workspace shows a minimal project-side Campfire integration.

It includes:

- `AGENTS.md` for project rules
- `.autonomous/example-task/` for a single-milestone task
- `.autonomous/rolling-task/` for a rolling task
- `scripts/` for thin local wrapper commands that a consumer repo can copy and adapt

The wrapper scripts intentionally stay small:

- `scripts/new_task.sh`
- `scripts/resume_task.sh`
- `scripts/enable_rolling_mode.sh`
- `scripts/automation_prompt_helper.sh`
- `scripts/verify_harness.sh`

By default they look for installed Campfire skills under `~/.codex/skills`.

For deterministic verification inside the Campfire repo, set:

```bash
CAMPFIRE_SKILLS_ROOT=/abs/path/to/Campfire/skills ./scripts/verify_harness.sh
```

Treat these scripts as a copy-and-adapt template for real project repos, not as another Campfire core layer.
