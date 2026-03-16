# CampfireBench

CampfireBench is the benchmark shape for Campfire-style long-running agent tasks.

The point is not just "did the agent solve the task." Campfire needs to measure:

- task success
- state fidelity
- resume fidelity
- replan quality
- validation quality
- orchestration overhead

## Why Campfire Needs Its Own Benchmark

Benchmarks like SWE-bench, Terminal-Bench, WebArena, GAIA, and AssistantBench are useful, but they do not directly measure Campfire's main claim:

- durable task state outside chat history
- clean resume from disk
- explicit slice transitions
- queue replenishment and course correction
- strong milestone validation
- bounded orchestration overhead

CampfireBench is meant to evaluate those properties directly.

## Core Dimensions

### 1. Success

Did the run reach the intended milestone or stop for a valid reason?

### 2. State Fidelity

Did the control plane stay accurate?

Examples:

- `status`
- `current milestone`
- `current slice`
- `heartbeat`
- `last_run.stop_reason`
- generated context files

### 3. Resume Fidelity

Could a new thread resume correctly from task state alone?

### 4. Replan Quality

When the queue was depleted or facts changed, did the task reframe cleanly and continue?

### 5. Validation Quality

Did `validated` actually correspond to meaningful evidence?

### 6. Overhead

How much orchestration cost did Campfire add?

Primary metrics:

- tokens spent on control-plane reload
- tokens spent on task-state updates
- wall-clock time spent on orchestration
- orchestration token ratio

## Scenario Families

CampfireBench should include three layers.

### Synthetic Lifecycle

Low implementation difficulty, high harness sensitivity.

Examples:

- start / complete slice
- resume after interrupt
- blocked then retry
- queue replenish
- state drift detection

### Repo-Integrated Medium Tasks

Real repo edits with 3 to 5 milestones.

Examples:

- fix and validate a bug across two resumptions
- reframe after a failed validation
- resume from a decision boundary

### True Long-Horizon Tasks

60 to 180 minute runs with interruption, replan, and evaluation pressure.

Examples:

- coding task with a forced resume and a forced blocker
- rolling run that must replenish its queue at least once
- long task that must stop on decision boundary instead of guessing

## Result Model

Each benchmark result should record:

- `scenario_id`
- `run_id`
- `status`
- `task_success`
- `state_fidelity`
- `resume_fidelity`
- `replan_quality`
- `validation_quality`
- `orchestration_tokens`
- `total_tokens`
- `orchestration_seconds`
- `notes`

Derived metrics:

- `orchestration_token_ratio = orchestration_tokens / total_tokens`
- `overall_score` from weighted dimensions

## Long-Term Memory Question

Campfire does not yet need a separate generic long-term memory system for operational state. The SQL control plane is already that memory for:

- current task status
- queue
- heartbeats
- sessions
- validations
- artifacts

What Campfire may eventually need is curated cross-task memory, not raw agent memory. That should be explicit and reviewable, for example:

- reusable findings
- repo-specific lessons
- benchmark-derived heuristics

CampfireBench should help answer whether that is actually necessary by tracking failures caused by:

- repeated forgetting across tasks
- repeated rediscovery of the same repo rules
- repeated bad replans despite prior findings

If those failure modes stay low, the SQL control plane plus explicit findings are probably enough.

## Initial Scope

The initial CampfireBench implementation should stay lightweight:

- scenario files on disk
- a small runner that validates scenarios and scores result files
- a verifier that keeps the benchmark scaffold healthy

That gives Campfire a stable benchmark contract before building full benchmark automation.
