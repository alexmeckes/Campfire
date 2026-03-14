# Runbook

## Workspace

- Root: examples/basic-workspace
- Task: rolling-task

## Boot / Setup

- No setup required for the example task
- Inspect `checkpoints.json.execution` for the run policy

## Validation

- Confirm the rolling execution policy exists
- Confirm the current milestone differs from the queued milestones
- Confirm the handoff prompt allows auto-advance
- Confirm the automation-ready prompt example stays aligned with the rolling task path

## Observability

- Logs: .autonomous/rolling-task/logs/
- Artifacts: .autonomous/rolling-task/artifacts/
- Findings: .autonomous/rolling-task/findings/
