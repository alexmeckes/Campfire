# Fixture Long Run Brief

This workspace is the canonical neutral long-run benchmark for CampfireBench.

## Benchmark Goal

Measure whether Campfire can:

- resume cleanly from disk
- sustain a rolling backlog
- validate work explicitly
- reframe when the queue runs thin
- stop on a deliberate decision boundary instead of guessing

## Seeded Milestones

1. `m1_source_map`
   - Confirm the source docs and inventory agree on the benchmark phases.
2. `m2_validation_report`
   - Tighten the validation notes and update the neutral report artifact.
3. `m3_blocker_drill`
   - Handle the seeded blocker drill without corrupting task state.
4. `m4_backlog_refresh`
   - Replenish the backlog from findings without inventing product work.
5. `m5_decision_stop`
   - Stop on the seeded decision boundary if no safe assumption exists.

## Seeded Signals

- blocker drill: `benchmark/reports/m3-blocker-journal.md`
- decision boundary: `benchmark/reports/m5-decision-note.md`
