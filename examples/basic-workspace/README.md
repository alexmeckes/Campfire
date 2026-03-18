# Example Workspace

This workspace shows a minimal project-side Campfire integration.

It includes:

- `AGENTS.md` for project rules
- `.autonomous/example-task/` for a single-milestone task
- `.autonomous/rolling-task/` for a rolling task
- `.claude/` for a minimal Claude Code adapter extension
- `scripts/` for thin local wrapper commands that a consumer repo can copy and adapt

The wrapper scripts intentionally stay small:

- `scripts/new_task.sh`
- `scripts/resume_task.sh`
- `scripts/enable_rolling_mode.sh`
- `scripts/automation_prompt_helper.sh`
- `scripts/automation_proposal_helper.sh`
- `scripts/verify_harness.sh`

The Claude adapter is also intentionally small:

- `.claude/settings.json`
- `.claude/commands/campfire-resume.md`
- `.claude/commands/campfire-new-task.md`
- `.claude/commands/campfire-start-slice.md`
- `.claude/commands/campfire-complete-slice.md`
- `.claude/hooks/campfire-hook-helper.py`
- `.claude/hooks/campfire-session-start.sh`
- `.claude/hooks/campfire-pre-tool.sh`
- `.claude/hooks/campfire-post-tool.sh`
- `.claude/hooks/campfire-statusline.sh`

By default they look for installed Campfire skills under `~/.codex/skills`.

Use `scripts/automation_prompt_helper.sh` when you only need task-only prompt text.
Use `scripts/automation_proposal_helper.sh` when you want schedule-agnostic automation metadata that also includes a suggested name and workspace roots.

For deterministic verification inside the Campfire repo, set:

```bash
CAMPFIRE_SKILLS_ROOT=/abs/path/to/Campfire/skills ./scripts/verify_harness.sh
```

Treat these scripts and `.claude/` files as a copy-and-adapt template for real project repos, not as another Campfire core layer.
