# milestone-029 automation proposal backlog

- The prompt helper removes copied prompt text, but recurring Codex App automations still require users to hand-build the suggested automation metadata around that prompt.
- The next leverage point is a helper that emits automation-ready proposal fields from Campfire state while still keeping schedule and workspace selection external.

## Proposed backlog

- `milestone-029`: add an automation proposal helper that emits a suggested automation name and task-only prompt from existing Campfire state
- `milestone-030`: add deterministic verification for automation proposal helper output and task-state selection
- `milestone-031`: document automation proposal helper usage in README and example guidance
- `milestone-032`: expose automation proposal helper guidance from `resume_task.sh` for rolling tasks
- `milestone-033`: add deterministic verification that `resume_task.sh` surfaces automation proposal guidance correctly

## Acceptance targets

- Campfire can derive a short, stable automation name plus a task-only prompt from an existing `.autonomous/<task>/` directory.
- The helper keeps cadence and workspace selection outside the generated proposal content.
- The verifier suite and resume guidance stay aligned with the new helper.
