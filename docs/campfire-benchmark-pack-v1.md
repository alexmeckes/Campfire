# Campfire Benchmark Pack v1

Benchmark Pack v1 is the first concrete benchmark set for Campfire after the core loop became stable enough to measure.

The goal is not to create a giant autonomous evaluator first. The goal is to answer a smaller question:

- does Campfire stay coherent on short, medium, long, and extra-long runs?

Pack v1 therefore mixes:

- short synthetic scenarios
- medium repo-integrated scenarios
- one real long-running self-hosted task
- one extra-long consumer-repo task

## Why This Pack Exists

Campfire now has:

- durable task state
- a SQL-backed control plane
- explicit slice transitions
- generated resume context
- verifier-backed adapters

That is enough stability to benchmark the harness itself instead of just chasing random failures.

Pack v1 is meant to answer:

- does state remain accurate over time?
- does a fresh session resume cleanly?
- does the harness stop at real decision boundaries?
- how much orchestration overhead does Campfire add?
- where does Campfire fail before subagents or stronger automations are justified?

## Pack Shape

Pack v1 has three layers.

### Layer 1: Short Mechanics

These should stay fast and deterministic. They isolate the harness.

1. `resume-after-interrupt`
   - Category: `synthetic_lifecycle`
   - Goal: prove a fresh session can continue from durable state alone.
   - Pass conditions:
     - resumed task matches prior milestone and slice
     - generated context remains accurate
     - no duplicate active slice is created

2. `state-drift-detection`
   - Category: `synthetic_lifecycle`
   - Goal: prove Campfire catches mismatches between task files and the control plane.
   - Pass conditions:
     - `doctor_task.sh` fails with a targeted mismatch
     - a corrected state re-validates cleanly

3. `queue-replenish`
   - Category: `synthetic_lifecycle`
   - Goal: prove rolling mode can consume a queue and reframe safely.
   - Pass conditions:
     - queue depth drops to threshold
     - reframe updates queued milestones without corrupting current state
     - task remains resumable

4. `blocked-then-unblock`
   - Category: `synthetic_lifecycle`
   - Goal: prove a blocked task records the stop correctly and resumes after unblock.
   - Pass conditions:
     - blocked status is durable
     - unblock path returns task to active work without losing prior evidence

5. `waiting-on-decision-stop`
   - Category: `synthetic_lifecycle`
   - Goal: prove Campfire stops instead of guessing through a product decision.
   - Pass conditions:
     - task records `waiting_on_decision`
     - no follow-on slice starts automatically
     - resume surface makes the decision boundary obvious

6. `no-active-slice-edit-guard`
   - Category: `synthetic_lifecycle`
   - Goal: prove adapters block edits when work has not been activated cleanly.
   - Pass conditions:
     - edit guard rejects file edits with no active slice
     - guard clears after slice activation

### Layer 2: Medium Reality Checks

These use real repo work but keep the scope bounded.

7. `repo-medium-validation`
   - Category: `repo_medium`
   - Goal: prove Campfire can complete a real 3 to 5 milestone task with at least one validation boundary.
   - Pass conditions:
     - final task state is coherent
     - at least one milestone requires explicit validation evidence
     - at least one resume occurs during the run

8. `adapter-parity`
   - Category: `repo_medium`
   - Goal: compare the Codex and Claude adapter paths on the same Campfire workflow.
   - Pass conditions:
     - both runs preserve task-state semantics
     - both stop for the same class of reasons
     - differences are recorded as adapter drift, not mistaken for model quality

### Layer 3: Long-Horizon Proof

These are expensive and should only run after the earlier layers are stable.

9. `self-hosted-long-run`
   - Category: `long_horizon`
   - Target duration: `90 to 120 minutes`
   - Candidate repo: `Campfire`
   - Candidate task slug: `improve-campfire`
   - Candidate task shape: real self-improvement or hardening backlog
   - Required events:
     - multiple milestones
     - at least one queue replenish
     - at least one explicit validation boundary
     - at least one correct stop or re-assess point
   - Success conditions:
     - state stays coherent
     - resumes work cleanly
     - stop reason is correct
     - orchestration overhead remains bounded

10. `consumer-repo-extra-long-run`
    - Category: `extra_long_horizon`
    - Target duration: `180 to 240 minutes`
    - Candidate repo: `lootidle`
    - Candidate task slug: `build-the-playable-vertical-slice`
    - Candidate task shape: real product work, not harness-only work
    - Required events:
      - at least 5 milestones
      - at least 2 resumes
      - at least 1 failed validation or blocker
      - at least 1 queue replenish
      - at least 1 real decision boundary or explicit no-assumption stop
    - Success conditions:
      - task remains coherent over hours
      - stop conditions remain correct
      - agent does not thrash or silently drift

## Pack v1 Run Order

Run Pack v1 in order.

1. Stabilize Layer 1.
2. Run Layer 2 once the short mechanics stop finding obvious harness bugs.
3. Run `self-hosted-long-run`.
4. Only then run `consumer-repo-extra-long-run`.

This ordering matters. The extra-long run is for proof, not for discovering basic harness bugs that the short scenarios should have caught first.

## Metrics

Record these for every scenario:

- `task_success`
- `state_fidelity`
- `resume_fidelity`
- `replan_quality`
- `validation_quality`
- `stop_correctness`
- `orchestration_tokens`
- `total_tokens`
- `orchestration_token_ratio`
- `orchestration_seconds`
- `human_interventions`
- `unexpected_replans`
- `bad_continuation_count`

For long and extra-long runs, also record:

- milestones completed
- queue replenishments
- verifier failures
- blockers encountered
- final stop reason
- whether the final stop reason was actually correct

## Pack v1 Success Criteria

Pack v1 is successful when:

- Layer 1 scenarios are stable and deterministic
- Layer 2 shows that real repo work preserves Campfire semantics
- the long run finishes or stops for a correct reason
- the extra-long run remains coherent for hours without silent drift

Pack v1 is not trying to prove maximum task completion rate yet. It is trying to prove that Campfire can stay mechanically correct over time.

## What Pack v1 Should Decide

The benchmark should drive the next architectural choice.

Examples:

- if failures cluster around stale state, improve control-plane hardening
- if failures cluster around validation weakness, strengthen verifiers
- if failures cluster around missed decision boundaries, improve stop and monitoring surfaces
- if failures show repeated decomposable side work, then a monitoring-sidecar subagent extension becomes justified

That means Pack v1 should decide whether subagent monitoring is worth building further, rather than assuming it in advance.
