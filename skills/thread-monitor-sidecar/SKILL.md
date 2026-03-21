---
name: thread-monitor-sidecar
description: Use when a rolling Codex App run should keep exactly one observer-only monitoring subagent alive for the current thread, reuse it across task changes, and retarget its task-specific monitor loop without letting it mutate durable Campfire task state.
---

# Thread Monitor Sidecar

Use this skill when Codex App should keep one visible monitoring sidecar subagent alive for the current thread instead of spawning a fresh monitor per task.

This is specifically a subagent-management skill. The skill is the instruction layer; the sidecar is the real delegated subagent that should remain visible in the thread UI for the duration of the run.

Pair it with:

- `$task-handoff-state` to read durable task state and locate the current task slug
- `$long-horizon-worker` when rolling execution is actively advancing slices
- `$course-corrector` when the active task changes because the plan actually changed

The underlying task-health primitive remains `./scripts/monitor_task_loop.sh <task-slug>` or the skill-path equivalent. The new rule is lifecycle, not ownership:

- keep one live monitor sidecar per thread
- reuse that same sidecar across slices and task changes
- when the active task changes, retarget the same sidecar instead of spawning a duplicate
- keep it observer-only and let it write only `.campfire/monitoring/` artifacts

## Workflow

1. Determine the active task slug from Campfire task state or the rendered resume prompt.
2. If the thread already has a live monitor sidecar, reuse it. Do not spawn a second monitor for the same thread.
3. If no monitor sidecar exists yet, spawn exactly one real sidecar subagent in the thread and keep its role limited to monitoring.
4. Inside that sidecar, run the repo-local `./scripts/monitor_task_loop.sh <task-slug>` wrapper when available. If the repo wrapper does not exist, use the bundled Campfire helper path.
5. When the parent switches to a different Campfire task in the same thread, send the existing sidecar the new task slug and monitoring command. The sidecar may stop the old task-local loop and start the new one, but the sidecar identity should stay the same.
6. If the parent run stops, the user pauses the thread, or the sidecar reports a real blocker or decision boundary, return control to the parent instead of widening scope.

## Guardrails

- Do not let the sidecar edit `checkpoints.json`, `handoff.md`, `progress.md`, or `.campfire/campfire.db`.
- Do not let the sidecar call `complete_slice.sh`, `enable_rolling_mode.sh`, or queue-reframe helpers on its own.
- Do not turn the sidecar into a scheduler, worker pool, or multi-task orchestrator.
- The sidecar may observe, summarize, and emit `.campfire/monitoring/alerts/` or related extension-local artifacts.
- The parent agent remains the single writer for durable task state and milestone transitions.

## Output Contract

Good sidecar outputs are:

- short health nudges
- drift or stall alerts
- suggestions such as `doctor_task.sh` or pause and reassess
- extension-local monitoring artifacts

Bad sidecar outputs are:

- silent durable task-state edits
- self-authorized milestone transitions
- broad implementation work that belongs to the parent agent
