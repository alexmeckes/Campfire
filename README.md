# Campfire

Campfire is a lightweight long-horizon Codex harness.

It keeps the workflow generic, keeps project rules local to each repo, and gives Codex durable task state outside chat history.

## Model

Campfire uses a small stack:

- `task-framer`
- `course-corrector`
- `long-horizon-worker`
- `task-evaluator`
- `task-handoff-state`

Each repo supplies its own `AGENTS.md`, docs, validators, and local wrappers.  
Each task lives under `.autonomous/<task>/`.

## Control Plane

Campfire now has a lightweight local control plane:

- `.autonomous/<task>/` remains the operator-facing task directory
- `.campfire/campfire.db` stores SQL-backed runtime state
- `.campfire/registry.json` provides a repo-wide task summary
- `.campfire/project_context.json` and `.autonomous/<task>/task_context.json` provide structured resume context

This is intentionally still single-agent and local-first. The skills stay as the Codex behavior layer; the control plane makes the workflow more mechanical and less prompt-dependent.

## Install

Install the skills into `~/.codex/skills`:

```bash
./scripts/install_skills.sh
```

Restart Codex App after installation so the skill list refreshes.

## Verify

Run the main repo verification:

```bash
./scripts/verify_repo.sh
```

Run the board smoke test:

```bash
cd apps/campfire-board
npm install
npm run test:smoke
```

## Quick Start

Create a task:

```bash
~/.codex/skills/task-handoff-state/scripts/init_task.sh --root /path/to/project "your objective"
```

Frame it if needed:

```text
Use $task-framer and $task-handoff-state to turn this objective into a concrete Campfire task.
```

Start a slice before editing project files:

```bash
~/.codex/skills/task-handoff-state/scripts/start_slice.sh --root /path/to/project --from-next --slice-title "Implement the next safe slice" your-task-slug
```

Resume in Codex App:

```text
Use $long-horizon-worker and $task-handoff-state to continue .autonomous/<task>/ and validate the next slice before stopping.
```

If `resume_task.sh` says the task is missing during a continue/resume request, stop and confirm the workspace plus task slug instead of bootstrapping a replacement task.

Complete the slice mechanically:

```bash
~/.codex/skills/task-handoff-state/scripts/complete_slice.sh --root /path/to/project --summary "Describe what validated." --next-step "Describe the next step." your-task-slug
```

Check consistency:

```bash
./scripts/doctor_task.sh <task-slug>
```

For long unattended runs, switch the task into rolling mode:

```bash
~/.codex/skills/task-handoff-state/scripts/enable_rolling_mode.sh --root /path/to/project your-task-slug --queue "milestone-002:Next slice" --queue "milestone-003:Follow-up slice"
```

For a manual-stop rolling run, use `--until-stopped`.

## Recurring Automation Patterns

Automations are optional. When you do want recurring runs, keep the automation prompt task-only and let the automation configuration own schedule and workspace.
Automations are best when the task already has stable Campfire state and a known task slug.

For the reusable patterns and prompt guidance, see [Automation patterns](/Users/alexmeckes/Downloads/Campfire/skills/task-handoff-state/references/automation-patterns.md).

## Campfire Board

Run the board locally:

```bash
cd apps/campfire-board
npm install
npm run dev
```

Run it as a small Electron window:

```bash
cd apps/campfire-board
npm install
npm run dev:desktop
```

Point it at specific repos:

```bash
CAMPFIRE_BOARD_REPOS=/abs/repo-one,/abs/repo-two npm run dev
```

The board reads `.autonomous/` plus `.campfire/`, so active slices, registry refreshes, heartbeats, and SQL-derived context can all show up without a full rescan.

## Example Workspace

`examples/basic-workspace/` is the consumer-repo template. It shows:

- `AGENTS.md`
- `campfire.toml`
- thin local wrapper scripts
- minimal example task state
- a wrapper verifier

Use it as the reference for adopting Campfire in a new project without forking the core skills.

## Docs

Use the focused docs for the deeper details:

- [Task state contract](/Users/alexmeckes/Downloads/Campfire/skills/task-handoff-state/references/task-state-contract.md)
- [Automation patterns](/Users/alexmeckes/Downloads/Campfire/skills/task-handoff-state/references/automation-patterns.md)
- [Campfire Board spec](/Users/alexmeckes/Downloads/Campfire/docs/campfire-board-spec.md)
- [Campfire v3 control plane](/Users/alexmeckes/Downloads/Campfire/docs/campfire-v3-control-plane.md)

## Principles

- Keep the skill layer thin and the control plane mechanical.
- Keep project rules local to the repo.
- Write durable state outside chat history.
- Make validation explicit and queryable.
- Prefer resumable work over session memory.
