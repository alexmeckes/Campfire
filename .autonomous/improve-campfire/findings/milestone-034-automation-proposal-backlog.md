# milestone-034 automation proposal backlog

- The automation-proposal backlog remains useful after the missing-resume guardrail landed.
- With resume semantics now safer across workspaces, Campfire can return to generating automation-ready proposal metadata without risking accidental task creation in the wrong repo.

## Proposed backlog

- `milestone-034`: add an automation proposal helper that emits a suggested automation name and task-only prompt from Campfire state
- `milestone-035`: add deterministic verification for automation proposal helper output and task-state selection
- `milestone-036`: document automation proposal helper usage in README and example guidance
- `milestone-037`: expose automation proposal helper guidance from `resume_task.sh` for rolling tasks
- `milestone-038`: add deterministic verification that `resume_task.sh` surfaces automation proposal guidance correctly
