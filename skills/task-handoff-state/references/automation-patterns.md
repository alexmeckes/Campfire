# Recurring Automation Patterns

Use this reference when a Campfire task should be resumed by a recurring Codex App automation instead of a one-off live thread or background task.

## Choose The Right Mode

- Use a live thread when you want to watch the task and steer it interactively.
- Use a background task when you want a one-off unattended run against an existing `.autonomous/<task>/`.
- Use a recurring automation when the same task should be revisited on a schedule, such as a nightly verifier sweep or a weekly backlog refresh.

Recurring automations work best when the task already has:

- a stable `.autonomous/<task>/` directory
- a rolling `execution` policy in `checkpoints.json`
- explicit stop conditions
- concrete validation commands in `runbook.md`

If the task already exists, prefer generating the prompt body from state instead of copying example text:

```bash
~/.codex/skills/task-handoff-state/scripts/automation_prompt_helper.sh <task-slug>
```

## Prompt Rules

Keep the automation prompt focused on the task itself.

- Keep schedule and workspace outside the prompt. The automation configuration should own cadence and workspace selection.
- Name the task directory explicitly, for example `.autonomous/release-triage/`.
- Mention the Campfire skills needed for the run.
- Bound planning and require task-state updates after each meaningful slice.
- Keep stop conditions explicit: blocker, decision boundary, budget limit, or manual pause.
- Tell the automation what to leave behind: `progress.md`, `handoff.md`, `checkpoints.json`, `artifacts.json`, and any new findings.

## Workspace Guidance

- Point the automation at one workspace root per task.
- For risky or long-lived git work, bootstrap the task in a dedicated worktree and keep the automation pointed at that worktree root.
- Keep generated evidence inside `.autonomous/<task>/` so each scheduled run can resume from local state instead of chat history.
- Prefer one stable task slug per automation. If the objective changes materially, create a new task instead of mutating the old one beyond recognition.

## Reusable Patterns

### Nightly Rolling Resume

Use when a known task should keep advancing while preserving its current backlog.

```text
Use $task-framer, $course-corrector, $long-horizon-worker, $task-evaluator, and $task-handoff-state to continue .autonomous/<task>/. Keep planning bounded, auto-advance through queued milestones, replenish the queue when policy allows and budget remains, update task state after each meaningful slice, and stop only on a real blocker, decision boundary, budget limit, or manual pause.
```

### Verifier Sweep

Use when the task mostly needs validation and state refresh instead of broad implementation.

```text
Use $task-evaluator and $task-handoff-state to inspect .autonomous/<task>/, rerun the strongest validation listed in runbook.md, refresh findings or artifacts only if evidence changed, and stop after updating task state with the current evaluation result.
```

### Weekly Backlog Refresh

Use when the queued milestones or assumptions may be stale after several runs.

```text
Use $task-framer, $course-corrector, and $task-handoff-state to review .autonomous/<task>/, tighten the next 2 to 3 milestones, refresh execution policy if needed, preserve prior progress, and leave a new handoff without broad implementation unless the new next slice is obvious and dependency-safe.
```

## Gating Rules

- If the task directory does not exist, stop and report that Campfire state needs to be created first.
- If the task is `waiting_on_decision`, do not guess past the decision boundary.
- If the task is `blocked`, prefer a narrow unblock attempt only when `runbook.md` already describes one.
- If the queued backlog is empty and `auto_reframe` is disabled, stop after leaving a handoff instead of inventing a new backlog silently.
