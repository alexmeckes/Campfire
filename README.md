# Campfire

Campfire is a lightweight control plane that sits on top of agent runtimes like Codex and Claude Code to support long-horizon, resumable engineering tasks.

It keeps the workflow generic, keeps project rules local to each repo, and gives agents durable task state outside chat history.

## Model

Campfire uses a small stack:

- `task-framer`
- `course-corrector`
- `long-horizon-worker`
- `task-evaluator`
- `task-handoff-state`
- `thread-monitor-sidecar`
- `task-retrospector`

Each repo supplies its own `AGENTS.md`, docs, validators, and local wrappers.  
Each repo also chooses a task root in `campfire.toml` via `default_task_root` (default: `.autonomous`).

`task-retrospector` is the improvement loop. It turns completed runs, failures, and benchmark regressions into benchmark, verifier, control-plane, or generated-skill follow-up candidates instead of relying on vague memory.
`thread-monitor-sidecar` is the rolling-run sidecar layer. It keeps one visible observer-only monitor subagent alive for the current thread and retargets it when the active Campfire task changes.

## Control Plane

Campfire now has a lightweight local control plane:

- `<task-root>/<task>/` remains the operator-facing task directory
- `.campfire/campfire.db` stores SQL-backed runtime state
- `.campfire/registry.json` provides a repo-wide task summary
- `.campfire/improvement_backlog.json` provides a repo-wide improvement queue
- `.campfire/project_context.json` and `<task-root>/<task>/task_context.json` provide structured resume context

This is intentionally still single-agent and local-first. The skills and adapters stay as the agent behavior layer; the control plane makes the workflow more mechanical and less prompt-dependent.

## Core Boundary

Campfire core should stay small.

The minimum loop is still the baseline:

- resume from disk
- activate a slice
- do work
- validate it
- write durable state
- stop cleanly

Campfire's current shared core is a little larger than that minimum because the shipped scripts and verifiers already rely on a few supporting surfaces:

- prompt-template rendering
- operator guidance persistence
- session lineage metadata
- skill inventory and generated context projections

The important rule from here forward is about growth: new capabilities should default to extensions unless they are required shared infrastructure for the single-agent control plane.

Features like automation helpers, generated-skill drafting, benchmark adapters, repo-specific wrappers, and app-specific integrations should still start as extensions layered on top of the core control plane.

For the explicit boundary, see [Campfire core vs extensions](/Users/alexmeckes/Downloads/Campfire/docs/campfire-core-vs-extensions.md).

## Install

Install the core Campfire skills into `~/.codex/skills`:

```bash
./scripts/install_skills.sh
```

Restart your agent client after installation so the skill list refreshes. Today Campfire ships:

- Codex-oriented skills under `~/.codex/skills`
- a repo-local Codex plugin bundle exposed through [/.agents/plugins/marketplace.json](/Users/alexmeckes/Downloads/Campfire/.agents/plugins/marketplace.json)
- a Claude Code adapter template under `examples/basic-workspace/.claude/`

If you want to test Campfire through the Codex plugin directory instead of direct skill installs, the repo now exposes a local `campfire-codex` plugin under [plugins/campfire-codex](/Users/alexmeckes/Downloads/Campfire/plugins/campfire-codex). It ships a thin Campfire workflow skill and relies on the target repo's local Campfire wrappers instead of copying the full control plane into the plugin cache.

## Verify

Run the main repo verification:

```bash
./scripts/verify_repo.sh
```

Run the benchmark scaffold verifier:

```bash
./scripts/verify_benchmark.sh
```

Run the board smoke test:

```bash
cd apps/campfire-board
npm install
npm run test:smoke
```

## Core Quick Start

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

Inspect the task state and use the emitted resume prompt:

```bash
./scripts/resume_task.sh <task-slug>
```

Resume in your agent client with the prompt or adapter output from that task. If you need to refer to the task directory directly, use the repo's configured `default_task_root` from `campfire.toml` rather than assuming `.autonomous/`.

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

For rolling Codex App runs, use `$thread-monitor-sidecar` to start or reuse one visible observer-only sidecar subagent for the current thread. Point it at the task-local monitor loop while the parent agent advances slices:

```bash
./scripts/monitor_task_loop.sh <task-slug>
```

Reuse that same sidecar if the active task changes later in the thread. The task-local monitor loop should write only `.campfire/monitoring/` artifacts and never mutate durable task state.

## Shared Workflow Utilities

Campfire already ships a few shared control-plane utilities beyond the minimal quick start. These are part of the current core workflow even though a brand-new repo may not need them on day one.

Examples:

```bash
./scripts/prompt_template_helper.sh --task-slug <task-slug> resume
./scripts/prompt_template_helper.sh --task-slug <task-slug> retrospective
./scripts/prompt_template_helper.sh benchmark
./scripts/queue_guidance.sh --mode interrupt_now --summary "Stop and inspect the failing verifier." <task-slug>
./scripts/queue_guidance.sh --mode next_boundary --summary "Revisit this after the current milestone." <task-slug>
./scripts/record_improvement_candidate.sh --task-slug <task-slug> --category skill_candidate --scope repo_local --title "Title" --problem "Problem" --next-action "Next action"
./scripts/promote_improvement.sh <candidate-id>
```

These are still shared Campfire surfaces, not repo-local plugins.

## Extensions

Extensions are where new capability should land first.

Current examples:

```bash
./scripts/draft_generated_skill.sh <candidate-id>
./skills/task-handoff-state/scripts/verify_draft_generated_skill.sh
./scripts/automation_proposal_helper.sh <task-slug>
./scripts/automation_schedule_scaffold.sh <task-slug>
```

For a Claude Code adapter that stays outside Campfire core, see [Claude Code adapter](/Users/alexmeckes/Downloads/Campfire/docs/claude-code-adapter.md).

For a first-pass subagent model that stays outside core, see [Subagent monitor extension](/Users/alexmeckes/Downloads/Campfire/docs/subagent-monitor-extension.md). For Codex rolling runs, the default extension pattern is one continuous visible monitor sidecar per thread, backed by `./scripts/monitor_task_loop.sh`, not a worker swarm.

For generated-skill and automation details, see the focused docs below.

For the full template list, see [Prompt templates](/Users/alexmeckes/Downloads/Campfire/skills/task-handoff-state/references/prompt-templates.md).

## Recurring Automation Patterns

Automations are optional. When you do want recurring runs, keep the automation prompt task-only and let the automation configuration own schedule and workspace.
Automations are best when the task already has stable Campfire state and a known task slug.

Use the prompt-only helper when you just need reusable prompt bodies:

```bash
./skills/task-handoff-state/scripts/automation_prompt_helper.sh <task-slug>
```

Use the proposal helper when you want schedule-agnostic metadata with a suggested name, prompt, and workspace roots:

```bash
./scripts/automation_proposal_helper.sh <task-slug>
```

Use the schedule scaffold helper when you want generic cadence suggestions and operator questions without committing to scheduler-specific syntax:

```bash
./scripts/automation_schedule_scaffold.sh <task-slug>
```

Use the helper layers intentionally:

- `automation_prompt_helper.sh` for task-only prompt bodies
- `automation_proposal_helper.sh` for names, prompts, and workspace roots
- `automation_schedule_scaffold.sh` for natural-language cadence guidance that still leaves schedule selection to the operator or automation layer

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

The board reads the repo task directory plus `.campfire/`. In the default layout that means `.autonomous/` plus `.campfire/`, so active slices, registry refreshes, heartbeats, and SQL-derived context can all show up without a full rescan.

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
- [Campfire core vs extensions](/Users/alexmeckes/Downloads/Campfire/docs/campfire-core-vs-extensions.md)
- [Claude Code adapter](/Users/alexmeckes/Downloads/Campfire/docs/claude-code-adapter.md)
- [Subagent monitor extension](/Users/alexmeckes/Downloads/Campfire/docs/subagent-monitor-extension.md)
- [CampfireBench](/Users/alexmeckes/Downloads/Campfire/docs/campfire-bench.md)
- [Campfire generated skills](/Users/alexmeckes/Downloads/Campfire/docs/campfire-generated-skills.md)
- [Task retrospection checklist](/Users/alexmeckes/Downloads/Campfire/skills/task-retrospector/references/retrospective-checklist.md)

## Principles

- Keep the skill layer thin and the control plane mechanical.
- Keep project rules local to the repo.
- Keep core small; push optional capability into extensions.
- Write durable state outside chat history.
- Make validation explicit and queryable.
- Prefer resumable work over session memory.
