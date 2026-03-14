# Course Correction Triggers

Use this reference when deciding whether a Campfire task should adjust course.

## Triggers

- a blocker changed the feasible implementation path
- an external dependency or environment assumption was false
- a new source doc changes the definition of done
- milestones were discovered to be in the wrong order
- one milestone should split into two
- a retry pattern is turning into thrash
- validation showed the current acceptance criteria are incomplete

## What To Update

When a trigger is real, update:

- `progress.md` with the reason for the change
- `plan.md` if milestones or criteria changed
- `runbook.md` if setup or validation changed
- `handoff.md` with the new next slice and stop reason if needed
- `checkpoints.json` with new `status`, `current`, `blocker`, or `last_run` fields
- `artifacts.json` if the correction depends on a new artifact or evidence source

## What Not To Do

- do not hide a blocker by pretending the plan is unchanged
- do not delete the old task history
- do not silently swap objectives
- do not keep retrying the same dead path without recording escalation

## Split Instead Of Correct

Create a new task instead of course-correcting the old one if:

- the objective changed materially
- the user now wants a different deliverable
- the old history would confuse the new task more than help it
