# Campfire

Campfire is a lightweight long-horizon Codex harness.

It keeps the workflow generic, keeps project rules local to each repo, and gives Codex durable task state outside chat history.

The design constraint is simple: if a feature is not required for a single agent to resume, work, validate, and stop cleanly, it should start as an extension instead of becoming Campfire core.

## Model

Campfire uses a small stack:

- `task-framer`
- `course-corrector`
- `long-horizon-worker`
- `task-evaluator`
- `task-handoff-state`
- `task-retrospector`

Each repo supplies its own `AGENTS.md`, docs, validators, and local wrappers.  
Each repo also chooses a task root in `campfire.toml` via `default_task_root` (default: `.autonomous`).

`task-retrospector` is the improvement loop. It turns completed runs, failures, and benchmark regressions into benchmark, verifier, control-plane, or generated-skill follow-up candidates instead of relying on vague memory.

## Control Plane

Campfire now has a lightweight local control plane:

- `<task-root>/<task>/` remains the operator-facing task directory
- `.campfire/campfire.db` stores SQL-backed runtime state
- `.campfire/registry.json` provides a repo-wide task summary
- `.campfire/improvement_backlog.json` provides a repo-wide improvement queue
- `.campfire/project_context.json` and `<task-root>/<task>/task_context.json` provide structured resume context

This is intentionally still single-agent and local-first. The skills stay as the Codex behavior layer; the control plane makes the workflow more mechanical and less prompt-dependent.

## Core Boundary

Campfire core should stay small.

Core is only the surface needed for the basic single-agent loop:

- resume from disk
- activate a slice
- do work
- validate it
- write durable state
- stop cleanly

Features like automation helpers, generated-skill drafting, benchmark adapters, repo-specific wrappers, and app-specific integrations should default to extensions layered on top of the core control plane.

For the explicit boundary, see [Campfire core vs extensions](/Users/alexmeckes/Downloads/Campfire/docs/campfire-core-vs-extensions.md).

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

Resume in Codex App with the prompt from that output. If you need to refer to the task directory directly, use the repo's configured `default_task_root` from `campfire.toml` rather than assuming `.autonomous/`.

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

## Optional Extensions

Print canonical operator prompts from state instead of rewriting them by hand:

```bash
./scripts/prompt_template_helper.sh --task-slug <task-slug> resume
./scripts/prompt_template_helper.sh --task-slug <task-slug> retrospective
./scripts/prompt_template_helper.sh benchmark
```

Persist operator guidance without hand-editing task state:

```bash
./scripts/queue_guidance.sh --mode interrupt_now --summary "Stop and inspect the failing verifier." <task-slug>
./scripts/queue_guidance.sh --mode next_boundary --summary "Revisit this after the current milestone." <task-slug>
```

Record a structured improvement candidate from a retrospective:

```bash
./scripts/record_improvement_candidate.sh --task-slug <task-slug> --category skill_candidate --scope repo_local --title "Title" --problem "Problem" --next-action "Next action"
```

Promote a reviewed candidate into a real follow-up task:

```bash
./scripts/promote_improvement.sh <candidate-id>
```

Inspect the generated skill discovery manifest when working with repo-local or task-local draft skills:

```bash
./scripts/refresh_registry.sh
cat .campfire/skill_inventory.json
```

Draft a generated skill from a structured improvement candidate:

```bash
./scripts/draft_generated_skill.sh <candidate-id>
```

Validate the draft-generated-skill helper and wrapper flow:

```bash
./skills/task-handoff-state/scripts/verify_draft_generated_skill.sh
```

For the full template list, see [Prompt templates](/Users/alexmeckes/Downloads/Campfire/skills/task-handoff-state/references/prompt-templates.md).

## Resume Prompt Pattern

When a repo does not yet have a local `resume_task.sh` wrapper, the minimal core prompt still looks like this:

```text
Use $long-horizon-worker and $task-handoff-state to continue <task-root>/<task>/ and validate the next slice before stopping.
```

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
