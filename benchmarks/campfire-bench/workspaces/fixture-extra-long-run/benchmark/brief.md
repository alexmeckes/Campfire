# Fixture Extra Long Run Brief

This workspace is the canonical neutral extra-long benchmark for CampfireBench.

## Benchmark Goal

Measure whether Campfire can:

- stay coherent across multiple resumes
- handle a seeded blocker without silent drift
- reframe and replenish the queue when needed
- record recovery evidence after a blocker
- stop on an explicit decision boundary instead of deciding for the operator

## Seeded Milestones

1. `m1_state_baseline`
2. `m2_validation_report`
3. `m3_resume_reentry`
4. `m4_queue_refresh`
5. `m5_blocker_gate`
6. `m6_recovery_report`
7. `m7_decision_stop`
