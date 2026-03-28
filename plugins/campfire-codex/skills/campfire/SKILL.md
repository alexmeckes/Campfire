---
name: campfire
description: Use Campfire's repo-local wrappers to resume, frame, validate, and continue long-horizon engineering tasks in repos that expose `campfire.toml` plus `./scripts/` helpers.
---

# Campfire Codex Plugin Skill

Use this skill when the current repo already exposes Campfire through:

- `campfire.toml`
- `./scripts/new_task.sh`
- `./scripts/resume_task.sh`
- `./scripts/start_slice.sh`
- `./scripts/complete_slice.sh`
- `./scripts/doctor_task.sh`

## Workflow

1. Inspect the repo root for `campfire.toml` and the local `./scripts/` wrappers.
2. If the objective is vague, frame a task with `./scripts/new_task.sh "<objective>"`.
3. If a task already exists, inspect it with `./scripts/resume_task.sh <task-slug>`.
4. Before implementation, activate a bounded slice with `./scripts/start_slice.sh ...`.
5. After the slice validates, close it mechanically with `./scripts/complete_slice.sh ...`.
6. If state looks inconsistent, use `./scripts/doctor_task.sh <task-slug>` before continuing.

## Boundaries

- Prefer the repo's local Campfire wrappers over plugin-internal logic.
- Keep durable task state under the repo's configured task root from `campfire.toml`.
- Do not invent new workflow layers if the repo already exposes the standard wrappers.
