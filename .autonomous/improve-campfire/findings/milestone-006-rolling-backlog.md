# Milestone-006 Rolling Backlog

## Goal

Use Campfire's new rolling execution policy on itself so the next Codex App run can keep moving without stopping after a single validated milestone.

## Current Queue

1. `milestone-006` - add a helper script for switching an existing task into rolling mode
2. `milestone-007` - add a dedicated rolling-task example under `examples/basic-workspace/`
3. `milestone-008` - document Codex App launch patterns for live-thread and background-task runs using rolling mode

## Run Policy

- mode: `rolling`
- planning slice: 10 minutes
- runtime budget: 120 minutes
- auto-advance: true
- stop only on: blocker, waiting on decision, budget limit, or manual pause

## Notes

- The next run should start at milestone-006, not at a generic planning step.
- Each validated milestone should advance into the next queued one if time remains.
