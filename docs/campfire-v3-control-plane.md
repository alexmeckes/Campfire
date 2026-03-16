# Campfire v3 Control Plane

## Purpose

This document defines a proposed Campfire v3 architecture that keeps the current lightweight skill model while moving runtime state out of ad hoc markdown and JSON editing.

The goal is to reduce reliance on prompt memory and make the workflow more mechanical without turning Campfire into a heavy multi-agent orchestration system.

## Design Goals

- Keep Campfire single-agent and local-first
- Preserve the current Codex skill workflow
- Make runtime state transactional and queryable
- Keep operator-facing markdown and artifacts
- Reduce the number of workflow-critical files the model must remember to read or write
- Make lifecycle transitions scriptable and deterministic
- Keep setup simple enough for consumer repos

## Non-Goals

- Do not replace skills with a standalone daemon
- Do not introduce a required server process
- Do not add multi-agent routing, mayor/deacon roles, or swarm semantics
- Do not remove the existing `.autonomous/<task>/` artifact layout
- Do not require cloud services

## Architectural Summary

Campfire v3 should use three layers:

1. `campfire.toml`
   Human-authored repo configuration
2. `campfire.db`
   SQLite runtime control plane
3. `.autonomous/<task>/`
   Artifacts, findings, and generated human views

This keeps the best parts of the current model:

- skills stay as the Codex-facing workflow layer
- the repo still has a readable local contract
- operators still get markdown handoffs and progress logs

But it moves runtime truth into a proper local database.

## Why SQLite

SQLite is the right default substrate for Campfire because it is:

- serverless
- local
- transactional
- easy to query from shell, Node, Python, and Electron
- a much smaller dependency than a workflow engine or versioned database

Campfire does not currently need:

- a server-backed orchestration runtime
- multi-operator merge semantics
- branch-aware database history

Those are better solved later, if needed, than built into v3 by default.

## Source of Truth Split

### Human-authored sources

- `campfire.toml`
- `AGENTS.md`
- project design docs and specs
- `findings/*.md`
- artifact files under `.autonomous/<task>/artifacts/`

### Runtime source of truth

- `campfire.db`

### Generated projections

- `.autonomous/<task>/handoff.md`
- `.autonomous/<task>/progress.md`
- `.autonomous/<task>/checkpoints.json`
- `.campfire/registry.json`
- `.campfire/improvement_backlog.json`
- `.campfire/skill_inventory.json`
- optional `.autonomous/<task>/task_context.json`
- optional `.campfire/project_context.json`

Generated task projections should also expose lightweight operator guidance when present:

- `task_context.json` should surface one active interrupt-now entry plus queued next-boundary follow-ups
- `registry.json` should surface active guidance count, follow-up count, and the active summary for boards
- `skill_inventory.json` should surface stable package names plus scope metadata for core, repo-local, and task-local skill surfaces
- path fields inside `skill_inventory.json` should be repo-relative rather than machine-local absolute paths

The main shift is:

- markdown becomes a projection
- runtime state is no longer authoritative in markdown

## Repository Config: `campfire.toml`

`campfire.toml` should describe stable repo intent only.

Suggested fields:

```toml
version = 1
project_name = "lootidle"
default_task_root = ".autonomous"
default_run_style = "bounded"

[source_docs]
priority = [
  "loot_goblins_ai_build_spec.md",
  "loot_goblins_game_design_doc.md",
  "loot_goblins_art_style_guide.md",
]

[skills]
default = [
  "task-framer",
  "course-corrector",
  "long-horizon-worker",
  "task-evaluator",
  "task-handoff-state",
]
optional = ["godot-interactive"]

[constraints]
stack = "godot4"
mobile_portrait = true
target_resolution = "360x640"
deterministic_combat = true

[task_defaults]
planning_slice_minutes = 15
runtime_budget_minutes = 120
min_runtime_minutes = 60
min_milestones_per_run = 3
max_milestones_per_run = 6
reframe_queue_below = 1
target_queue_depth = 4

[[validators]]
id = "gdlint"
label = "GDScript lint"
kind = "static"
command = "gdlint $(rg --files scripts -g '*.gd' | sort)"

[[validators]]
id = "headless_runtime"
label = "Headless Godot validation"
kind = "runtime"
command = "/opt/homebrew/bin/godot --headless --path {{repo_root}} --script {{artifact_path}}"
```

Rules:

- tasks do not live in `campfire.toml`
- heartbeats do not live in `campfire.toml`
- current milestone does not live in `campfire.toml`
- validators are named and reusable by ID

## Database: `campfire.db`

`campfire.db` is the authoritative control plane.

### Core tables

#### `projects`

One row per repo root.

- `id`
- `root_path`
- `name`
- `config_version`
- `created_at`
- `updated_at`

#### `tasks`

The top-level task record.

- `id`
- `project_id`
- `slug`
- `objective`
- `status`
- `phase`
- `run_mode`
- `run_style`
- `created_at`
- `updated_at`
- `completed_at`

Status values:

- `ready`
- `in_progress`
- `blocked`
- `waiting_on_decision`
- `validated`
- `completed`

#### `milestones`

Stable task milestones.

- `id`
- `task_id`
- `milestone_key`
- `title`
- `status`
- `ordinal`
- `acceptance_json`
- `dependencies_json`
- `notes`
- `created_at`
- `updated_at`

#### `slices`

Execution-sized work units within a milestone.

- `id`
- `task_id`
- `milestone_id`
- `slice_key`
- `title`
- `status`
- `started_at`
- `ended_at`
- `summary`
- `created_at`
- `updated_at`

#### `queue_entries`

The real queued backlog.

- `id`
- `task_id`
- `milestone_id`
- `position`
- `source`
- `created_at`

`source` examples:

- `framed`
- `auto_reframed`
- `course_corrected`
- `manual`

#### `guidance_entries`

Lightweight operator guidance that stays local to the task instead of becoming a scheduler.

- `id`
- `task_id`
- `active`
- `position`
- `mode`
- `summary`
- `details`
- `source`
- `created_at`

`mode` values:

- `interrupt_now`
- `next_boundary`

Rules:

- allow at most one active interrupt-now entry per task
- keep next-boundary entries ordered and local to the task
- do not use this table to model multi-agent routing, resource scheduling, or future cron-style work

#### `sessions`

Session-level lifecycle.

- `id`
- `task_id`
- `started_at`
- `ended_at`
- `run_id`
- `parent_run_id`
- `lineage_kind`
- `branch_label`
- `stop_reason`
- `summary`

Rules:

- `run_id` should be stable enough for benchmark results or retrospective evidence to point at a specific branch
- `parent_run_id` should link retry, course-corrected, or benchmark-repro branches back to the run they came from
- lineage stays local to the existing single-agent session model rather than becoming a general branch-history database

#### `events`

Append-only history.

- `id`
- `task_id`
- `session_id`
- `milestone_id`
- `slice_id`
- `event_type`
- `payload_json`
- `created_at`

Event types:

- `task_created`
- `slice_started`
- `slice_completed`
- `milestone_validated`
- `course_corrected`
- `auto_advanced`
- `auto_reframed`
- `blocked`
- `waiting_on_decision`
- `validation_recorded`

#### `heartbeats`

One current liveness snapshot per task.

- `task_id`
- `session_id`
- `state`
- `session_started_at`
- `last_seen_at`
- `milestone_key`
- `slice_key`
- `summary`
- `touched_path`
- `source`

Heartbeat states:

- `active`
- `idle`
- `blocked`
- `waiting_on_decision`
- `completed`

#### `validations`

Proof that a slice or milestone actually passed.

- `id`
- `task_id`
- `milestone_id`
- `slice_id`
- `validator_id`
- `status`
- `artifact_path`
- `summary`
- `created_at`

Validation status:

- `passed`
- `failed`
- `partial`

#### `artifacts`

Indexed outputs that matter to operators and evaluators.

- `id`
- `task_id`
- `milestone_id`
- `slice_id`
- `path`
- `kind`
- `reason`
- `created_at`

#### `improvement_candidates`

Structured improvement work produced by retrospection or benchmark failures.

- `id`
- `project_id`
- `task_id`
- `candidate_id`
- `source_type`
- `source_task_slug`
- `source_milestone_key`
- `source_run_id`
- `title`
- `category`
- `scope`
- `promotion_state`
- `problem`
- `why_not_script`
- `evidence_json`
- `trigger_pattern_json`
- `proposed_skill_name`
- `proposed_skill_purpose`
- `confidence`
- `next_action`
- `promoted_task_slug`
- `output_path`
- `created_at`
- `updated_at`

#### `blockers`

- `id`
- `task_id`
- `milestone_id`
- `slice_id`
- `status`
- `blocker_type`
- `summary`
- `attempts`
- `next_action`
- `created_at`
- `resolved_at`

#### `decisions`

- `id`
- `task_id`
- `milestone_id`
- `slice_id`
- `question`
- `status`
- `answer`
- `created_at`
- `resolved_at`

## Recommended Query Model

The widget and local CLI should rely on DB-derived views instead of reparsing markdown.

Suggested views:

- `v_task_board`
- `v_task_current_slice`
- `v_task_latest_validation`
- `v_task_latest_event`
- `v_task_queue_depth`
- `v_task_health`

This is the key ergonomic win:

- the board should query one surface
- it should not infer state by scraping several files

## Command Surface

Campfire v3 should expose a small deterministic command layer.

It can begin as shell scripts plus `sqlite3`, then later become a tiny CLI if needed.

### Initialization

- `campfire init`
  - validate `campfire.toml`
  - create `campfire.db`
  - seed `projects`

### Task creation and framing

- `campfire task create "<objective>" --slug foo`
- `campfire task frame foo`
- `campfire task queue foo --milestone m2`
- `campfire task reframe foo`

### Lifecycle transitions

- `campfire task start-slice foo --from-next --slice-title "..."`
- `campfire task complete-slice foo --status validated --summary "..."`
- `campfire task block foo --type env --summary "..."`
- `campfire task request-decision foo --question "..."`
- `campfire task heartbeat foo --summary "..."`

### Operator support

- `campfire task doctor foo`
- `campfire task context foo`
- `campfire render foo`
- `campfire registry refresh`
- `campfire board snapshot`
- `campfire improvement record`
- `campfire improvement promote`

## Command Semantics

### `task start-slice`

Must:

- open or reuse a session
- pick the active milestone
- create/update the active slice
- set `tasks.status = in_progress`
- set `heartbeats.state = active`
- append `slice_started`
- render current projections

### `task complete-slice`

Must:

- close the active slice
- append `slice_completed`
- update milestone/task state
- record stop reason if the slice ended the current run
- update heartbeat to `idle`, `blocked`, `waiting_on_decision`, or `completed`
- render current projections

### `task doctor`

Must fail if:

- task status and heartbeat disagree
- current milestone is missing
- active slice is missing for `in_progress` tasks
- queued milestones reference missing milestone rows
- validation artifacts referenced in DB do not exist
- generated files are stale relative to DB timestamps

This is the main mechanical backstop against prompt drift.

## Generated Projections

These files stay because they are useful to humans and compatible with the current workflow.

### `handoff.md`

Generated from:

- current task status
- active milestone/slice
- next slice
- stop reason
- canonical resume prompt

### `progress.md`

Generated from:

- event log
- validation summaries
- session summaries

### `checkpoints.json`

Compatibility output for older board or skill consumers.

It should be rendered from DB, not edited directly.

### `.campfire/registry.json`

Board-facing projection across all tasks in a repo.

It should be rendered from DB, not rebuilt by scanning task directories for runtime truth.

### `.campfire/improvement_backlog.json`

Improvement-facing projection across benchmark, verifier, skill, control-plane, and repo-local follow-up candidates.

It should be rendered from DB, not maintained by hand.

## Skill Integration

Skills remain important in v3.

They just stop carrying so much hidden state.

### `$task-framer`

Responsibilities:

- read source docs from `campfire.toml`
- propose milestone structure
- call framing commands that persist milestones and queue entries

It should not hand-edit milestone queues in markdown as the primary workflow.

### `$long-horizon-worker`

Responsibilities:

- read DB-backed task context
- call `task start-slice`
- perform the work
- update heartbeat during long slices if needed
- call `task complete-slice`

It should not be responsible for manually keeping several files coherent.

### `$task-evaluator`

Responsibilities:

- read acceptance criteria from `milestones.acceptance_json`
- look up validator IDs from `campfire.toml`
- record validation results in `validations`
- append evaluation events

### `$course-corrector`

Responsibilities:

- update milestone order
- update queue entries
- append `course_corrected`
- preserve task/session continuity

### `$task-handoff-state`

Responsibilities:

- render `handoff.md`
- render `progress.md`
- render `checkpoints.json`
- render `registry.json`
- expose canonical resume output

This skill becomes mostly a projection and operator-facing surface, not the storage engine.

## Keeping the Skills Lightweight

The skill framework stays lightweight if the split is:

- skills decide behavior
- commands enforce transitions
- DB stores truth
- markdown is generated

That means:

- prompts stay short
- canonical resume, retrospective, benchmark, and promotion prompts can come from one small template layer instead of drifting across scripts
- the agent still gets specialized guidance
- fewer workflow failures depend on memory

Campfire should not become “a database that replaced the skills.”
It should become “a skill framework with a real local memory/control plane.”

## Migration Strategy

Use a phased migration.

### Phase 1: dual-write

- add `campfire.toml`
- add `campfire.db`
- new lifecycle helpers write DB and current files

### Phase 2: generated projections

- `handoff.md`, `progress.md`, `checkpoints.json`, and `registry.json` are rendered from DB
- runtime logic stops editing markdown directly

### Phase 3: runtime reads DB first

- board reads DB-derived registry
- command layer becomes authoritative
- markdown parsing is no longer used for runtime decisions

### Phase 4: import old tasks

Add:

- `campfire import-task .autonomous/<task>`

This command should:

- create task/milestone/slice rows
- import current queue
- import validation history where possible
- preserve existing artifacts and findings

## Compatibility Strategy

Campfire v3 should continue to support:

- existing `.autonomous/<task>/artifacts/`
- existing `findings/*.md`
- existing operator expectation of `handoff.md`
- current board widget with minimal changes

So the migration should preserve the outer ergonomics even while runtime storage changes.

## Open Questions

### Should SQL be accessed through shell scripts or a tiny CLI?

Recommendation:

- begin with shell scripts plus `sqlite3`
- move to a tiny CLI only if the command surface becomes too awkward

### Should `plan.md` remain human-authored?

Recommendation:

- yes, but only for narrative planning and notes
- milestone truth should live in DB

### Should task artifacts still live under `.autonomous/<task>/`?

Recommendation:

- yes
- the DB should index them, not replace them

### Should the widget read DB directly?

Recommendation:

- eventually yes, or via a DB-derived registry
- avoid reparsing markdown once the DB exists

## Recommended Minimum v3

The smallest useful version is:

- `campfire.toml`
- `campfire.db`
- `task create`
- `task start-slice`
- `task complete-slice`
- `task doctor`
- generated `handoff.md`
- generated `progress.md`
- generated `registry.json`

That is enough to meaningfully reduce prompt and markdown dependence without overbuilding the system.

## Decision

Campfire v3 should keep the lightweight skill framework and add a SQLite control plane behind it.

The intended model is:

- skills remain the Codex UX layer
- SQLite becomes the runtime source of truth
- markdown remains the human/operator projection
- lifecycle helpers become deterministic transitions over the DB
