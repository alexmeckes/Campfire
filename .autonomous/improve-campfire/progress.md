# Progress Log

## 2026-03-14

- Task created.
- Objective: dogfood Campfire on itself and add the blocked-run lifecycle verifier
- Next slice: define the first milestone and validation target.

## 2026-03-14 milestone-001

- Changed: added repo-local AGENTS.md plus scripts/new_task.sh and scripts/resume_task.sh so Campfire can use its own long-horizon workflow.
- Changed: added skills/task-handoff-state/scripts/verify_blocked_retry.sh and wired it into scripts/verify_repo.sh and README.md.
- Validation: ran ./scripts/verify_repo.sh successfully after adding the blocked and retry verifier.
- Blockers: none.
- Next slice: choose the next Campfire improvement milestone.

## 2026-03-14 milestone-002

- Changed: added the generic task-framing and course-correction skills so Campfire now covers task formation, execution, state, and re-planning.
- Changed: wired the new skills into install_skills.sh, verify_repo.sh, README.md, and AGENTS.md.
- Validation: ran ./scripts/verify_repo.sh successfully after adding the new skills and installer wiring.
- Blockers: none.
- Next slice: choose the next Campfire improvement milestone.

## 2026-03-14 milestone-003

- Changed: added skills/task-handoff-state/scripts/verify_course_correction.sh to simulate a real re-plan and prove the corrected milestone becomes the resume target.
- Changed: updated verify_repo.sh, README.md, and the task-state contract to treat `course_corrected` as a first-class stop reason.
- Validation: ran ./skills/task-handoff-state/scripts/verify_course_correction.sh and ./scripts/verify_repo.sh successfully.
- Blockers: none.
- Next slice: choose the next Campfire improvement milestone.

## 2026-03-14 milestone-004 framing

- Changed: framed the next unattended Campfire milestone as `task-evaluator skill and evaluator-focused verification coverage`.
- Changed: added a milestone brief with bounded planning and execution slices for a roughly two-hour run.
- Validation: updated plan.md, runbook.md, handoff.md, checkpoints.json, and artifacts.json to point at milestone-004.
- Blockers: none.
- Next slice: spend one bounded slice framing the evaluator scope, then implement the skill, wire it into the repo, and validate with verify_repo.sh.

## 2026-03-14 milestone-004

- Changed: added the generic `task-evaluator` skill with agent metadata and an evaluation checklist reference.
- Changed: added `skills/task-handoff-state/scripts/verify_task_evaluation.sh` to simulate an independent milestone evaluation and validated handoff.
- Changed: wired the evaluator into install_skills.sh, verify_repo.sh, README.md, AGENTS.md, and the task-state docs.
- Validation: ran ./skills/task-handoff-state/scripts/verify_task_evaluation.sh and ./scripts/verify_repo.sh successfully.
- Blockers: none.
- Next slice: choose the next Campfire improvement milestone.

## 2026-03-14 milestone-005

- Changed: added rolling execution policy to the task-state contract and checkpoint normalization so Campfire can distinguish single-milestone runs from rolling Codex App runs.
- Changed: updated the framing, execution, course-correction, and evaluation skills to honor rolling auto-advance semantics.
- Changed: added `skills/task-handoff-state/scripts/verify_rolling_execution.sh` and wired it into the repo verifier.
- Changed: updated the repo-local task wrappers to prefer the repo skill copies over stale global installs, then refreshed the global skill install with `./scripts/install_skills.sh`.
- Validation: ran ./skills/task-handoff-state/scripts/verify_rolling_execution.sh, ./scripts/verify_repo.sh, and ./scripts/resume_task.sh improve-campfire successfully.
- Blockers: none.
- Next slice: start milestone-006 and keep moving through the rolling backlog until a real stop condition appears.

## 2026-03-14 milestone-006

- Changed: added `skills/task-handoff-state/scripts/enable_rolling_mode.sh` plus the repo wrapper `scripts/enable_rolling_mode.sh` so an existing Campfire task can be switched into rolling mode explicitly.
- Changed: added `skills/task-handoff-state/scripts/verify_enable_rolling_mode.sh` and wired it into `scripts/verify_repo.sh`.
- Validation: ran ./skills/task-handoff-state/scripts/verify_enable_rolling_mode.sh and ./scripts/verify_repo.sh successfully.
- Blockers: none.
- Next slice: auto-advance into the rolling example milestone.

## 2026-03-14 milestone-007

- Changed: added `examples/basic-workspace/.autonomous/rolling-task/` as a dedicated rolling-task example with execution policy, queued milestones, and a rolling handoff.
- Validation: rolling example files are checked by ./scripts/verify_repo.sh.
- Blockers: none.
- Next slice: auto-advance into the Codex App launch-pattern docs milestone.

## 2026-03-14 milestone-008

- Changed: documented Codex App live-thread and background-task rolling launch patterns in README.md and updated the task-state docs to expose the rolling helper.
- Validation: ran ./scripts/verify_repo.sh successfully after the docs, helper, and example updates.
- Blockers: none.
- Next slice: choose the next Campfire improvement milestone.

## 2026-03-14 milestone-009 framing

- Course correction: the rolling verifier suite proved success-driven auto-advance, but it did not yet prove the two other common Codex App stop conditions: `budget_limit` and `waiting_on_decision`.
- Changed: framed a new rolling backlog for `milestone-009` through `milestone-011` and recorded it in `plan.md`, `handoff.md`, `checkpoints.json`, and `findings/milestone-009-rolling-stop-conditions.md`.
- Validation: reviewed the new milestone brief and confirmed the next three milestones are dependency-safe and independently verifiable.
- Blockers: none.
- Next slice: implement the budget-limit and waiting-on-decision verifiers, then wire their coverage into repo verification and docs.

## 2026-03-14 milestone-009

- Changed: added `skills/task-handoff-state/scripts/verify_budget_limit.sh` to simulate a rolling run that pauses on `budget_limit` while preserving the active milestone and queued backlog.
- Validation: ran ./skills/task-handoff-state/scripts/verify_budget_limit.sh successfully.
- Blockers: none.
- Next slice: auto-advance into the waiting-on-decision verifier milestone.

## 2026-03-14 milestone-010

- Changed: added `skills/task-handoff-state/scripts/verify_waiting_on_decision.sh` to simulate a rolling run that pauses at a real decision boundary without consuming the queued backlog.
- Validation: ran ./skills/task-handoff-state/scripts/verify_waiting_on_decision.sh successfully.
- Blockers: none.
- Next slice: auto-advance into the docs and repo-wiring milestone.

## 2026-03-14 milestone-011

- Changed: wired the new stop-condition verifiers into `scripts/verify_repo.sh` and documented the preserved-backlog behavior in `README.md`, `skills/task-handoff-state/SKILL.md`, and `skills/task-handoff-state/references/task-state-contract.md`.
- Validation: ran ./scripts/verify_repo.sh successfully and recorded the evaluation result in `findings/milestone-011-evaluation.md`.
- Blockers: none.
- Next slice: choose the next Campfire improvement milestone.

## 2026-03-14 milestone-012

- Course correction: rolling mode was still backlog-bounded, which meant a run could stop early even when budget remained simply because the queue was empty.
- Changed: extended the rolling execution contract, helper defaults, and resume output to support bounded queue replenishment with `auto_reframe`, queue-depth thresholds, and per-run reframe caps.
- Validation: ran ./skills/task-handoff-state/scripts/verify_enable_rolling_mode.sh successfully after adding the new rolling policy fields.
- Blockers: none.
- Next slice: add deterministic proof that a rolling run can replenish its own queue before stopping.

## 2026-03-14 milestone-013

- Changed: added `skills/task-handoff-state/scripts/verify_rolling_reframe.sh` to simulate a rolling run that replenishes its own queue when depth falls below the configured threshold.
- Validation: ran ./skills/task-handoff-state/scripts/verify_rolling_reframe.sh successfully.
- Blockers: none.
- Next slice: wire the dynamic rolling behavior into README, example task state, and repo verification.

## 2026-03-14 milestone-014

- Changed: wired `verify_rolling_reframe.sh` into `scripts/verify_repo.sh`, updated the rolling example state, and documented dynamic queue replenishment in `README.md`, `skills/task-handoff-state/SKILL.md`, and `skills/task-handoff-state/references/task-state-contract.md`.
- Validation: ran ./scripts/verify_repo.sh successfully and recorded the evaluation result in `findings/milestone-014-evaluation.md`.
- Blockers: none.
- Next slice: choose the next Campfire improvement milestone.

## 2026-03-14 milestone-015 framing

- Changed: framed the next Campfire backlog around optional worktree-aware bootstrapping for git repos and recorded it in `plan.md`, `handoff.md`, `checkpoints.json`, and `findings/milestone-015-worktree-backlog.md`.
- Validation: reviewed the roadmap and repo priorities, then confirmed the new three-milestone backlog is dependency-safe and keeps Campfire generic for both git and non-git workspaces.
- Blockers: none.
- Next slice: implement a worktree-aware task bootstrap helper for git repos, then verify deterministic fallback behavior for non-git workspaces.

## 2026-03-14 milestone-015

- Changed: added `skills/task-handoff-state/scripts/bootstrap_task.sh` and updated `scripts/new_task.sh` so Campfire can bootstrap a task in a dedicated git worktree when requested.
- Changed: recorded workspace strategy metadata in `checkpoints.json` and surfaced it in `resume_task.sh`.
- Validation: ran ./skills/task-handoff-state/scripts/verify_worktree_bootstrap.sh successfully after adding the bootstrap path and workspace metadata.
- Blockers: none.
- Next slice: wire the new bootstrap verifier into repo verification and document when to use the worktree path.

## 2026-03-14 milestone-016

- Changed: added `skills/task-handoff-state/scripts/verify_worktree_bootstrap.sh` to cover both git worktree bootstrap and deterministic non-git fallback behavior.
- Validation: ran ./skills/task-handoff-state/scripts/verify_worktree_bootstrap.sh successfully.
- Blockers: none.
- Next slice: auto-advance into the docs and guidance milestone.

## 2026-03-14 milestone-017

- Changed: wired the worktree bootstrap verifier into `scripts/verify_repo.sh`, documented worktree-aware bootstrapping in `README.md` and `skills/task-handoff-state/SKILL.md`, and updated example guidance in `examples/basic-workspace/AGENTS.md`.
- Validation: ran ./scripts/verify_repo.sh successfully and recorded the evaluation result in `findings/milestone-017-evaluation.md`.
- Blockers: none.
- Next slice: use one bounded reframe to queue the next automation-pattern backlog now that the worktree backlog is complete.

## 2026-03-14 milestone-018 framing

- Auto reframe: queue depth reached zero after the worktree backlog completed, so the run spent one bounded planning slice replenishing the next backlog around recurring Codex App automation patterns.
- Changed: recorded the next automation backlog in `plan.md`, `handoff.md`, `checkpoints.json`, and `findings/milestone-018-automation-backlog.md`.
- Validation: reviewed the roadmap and confirmed the new automation backlog is the next best generic Campfire improvement area.
- Blockers: none.
- Next slice: add a reusable automation-pattern reference for recurring Codex App runs.

## 2026-03-14 rolling-semantics-fix

- Changed: updated the rolling contract, worker/evaluator docs, and resume output so `auto_advanced` and `auto_reframed` are stored as `last_run.events` instead of terminal stop reasons.
- Changed: updated the rolling execution and rolling reframe verifiers plus the example rolling task to stop for a real reason like `manual_pause` after the mid-run transition is recorded.
- Validation: ran `./skills/task-handoff-state/scripts/verify_rolling_execution.sh`, `./skills/task-handoff-state/scripts/verify_rolling_reframe.sh`, `./scripts/verify_repo.sh`, and `./scripts/resume_task.sh improve-campfire`.
- Blockers: none.
- Next slice: continue milestone-018 by adding the automation-pattern reference and automation-ready guidance backlog.

## 2026-03-14 milestone-018

- Changed: added `skills/task-handoff-state/references/automation-patterns.md` and linked it from the generic task-state skill so recurring Codex App automations have a reusable Campfire reference.
- Validation: reviewed the new reference and confirmed it covers launch mode choice, prompt rules, workspace guidance, and reusable recurring patterns.
- Blockers: none.
- Next slice: add deterministic coverage and concrete example guidance for automation-ready prompts.

## 2026-03-14 milestone-019

- Changed: added `skills/task-handoff-state/scripts/verify_automation_patterns.sh` and wired it into `scripts/verify_repo.sh`.
- Changed: added `examples/basic-workspace/.autonomous/rolling-task/findings/automation-ready.md` plus related example updates so the automation guidance is visible in a real rolling task.
- Validation: ran `./skills/task-handoff-state/scripts/verify_automation_patterns.sh` successfully.
- Blockers: none.
- Next slice: document the recurring automation patterns in README and example guidance, then evaluate the backlog.

## 2026-03-14 milestone-020

- Changed: documented recurring automation patterns in `README.md`, `examples/basic-workspace/AGENTS.md`, and the rolling example task metadata.
- Changed: recorded the backlog evaluation in `findings/milestone-020-evaluation.md`.
- Validation: ran `./scripts/verify_repo.sh` successfully after adding the automation reference, verifier, and example guidance.
- Blockers: none.
- Next slice: use one bounded reframe to queue the next automation-helper backlog now that the recurring automation backlog is complete.

## 2026-03-14 milestone-021 framing

- Auto reframe: queue depth reached zero after the recurring automation backlog completed, so the run spent one bounded planning slice framing the next backlog around automation prompt helpers.
- Changed: recorded the next backlog in `plan.md`, `handoff.md`, `checkpoints.json`, and `findings/milestone-021-automation-helper-backlog.md`.
- Validation: reviewed the roadmap and confirmed the new helper backlog is the next dependency-safe improvement after the automation-pattern docs.
- Blockers: none.
- Next slice: add a helper that emits task-only automation prompt variants from existing Campfire state.

## 2026-03-14 milestone-021 course-correction

- Course correction: the user reported that Campfire still felt like five-minute bursts, so the automation-helper backlog was deferred in favor of strengthening the autonomous rolling floor itself.
- Changed: recorded the reprioritization in `findings/milestone-021-autonomy-floor-course-correction.md` and rewrote the forward backlog around minimum runtime, minimum milestone floors, and external-only `manual_pause`.
- Validation: reviewed the current rolling execution policy and confirmed that `max_milestones_per_run: 3`, queue depth `3`, and `manual_pause` in `continue_until` were the concrete reasons the runs stayed too short.
- Blockers: none.
- Next slice: enforce stronger autonomous defaults in the rolling helper and task-state contract.

## 2026-03-14 milestone-021

- Changed: updated the rolling helper, checkpoint normalization, and resume output to support `min_runtime_minutes`, `min_milestones_per_run`, stronger queue/reframe defaults, and external-only `manual_pause`.
- Changed: updated the worker, framer, evaluator, task-state skill, and task-state contract so autonomous runs do not voluntarily self-pause before the configured floor unless a blocker, decision boundary, or budget limit forces a real stop.
- Validation: reviewed the updated helper and contract together to confirm the defaults now target longer unattended runs.
- Blockers: none.
- Next slice: add deterministic verifier coverage for the new autonomous floor and update the rolling example state.

## 2026-03-14 milestone-022

- Changed: added `skills/task-handoff-state/scripts/verify_autonomous_floor.sh` and updated `verify_enable_rolling_mode.sh` so Campfire proves the stronger floor defaults and the absence of internal `manual_pause` in autonomous `continue_until`.
- Changed: updated `scripts/verify_repo.sh` to include the new verifier and aligned the example rolling task state with the stronger autonomy floor.
- Validation: ran `./skills/task-handoff-state/scripts/verify_autonomous_floor.sh`, `./skills/task-handoff-state/scripts/verify_enable_rolling_mode.sh`, and `./scripts/verify_repo.sh` successfully.
- Blockers: none.
- Next slice: document the autonomy floor behavior in README and example guidance, then evaluate the backlog.

## 2026-03-14 milestone-023

- Changed: documented the autonomy floor in `README.md`, the rolling example handoff, and the task-state docs, then recorded the evaluation in `findings/milestone-023-evaluation.md`.
- Validation: ran `./scripts/verify_repo.sh` successfully after the policy, verifier, and example updates.
- Blockers: none.
- Next slice: use one bounded reframe to restore the deferred automation-helper backlog with a deeper queue.

## 2026-03-14 milestone-024 framing

- Auto reframe: after the autonomy-floor backlog validated, the next bounded planning slice restored the deferred automation-helper work as a deeper queue.
- Changed: recorded the restored backlog in `plan.md`, `handoff.md`, `checkpoints.json`, and `findings/milestone-024-automation-helper-backlog.md`.
- Validation: reviewed the roadmap and confirmed the restored backlog now has enough depth to benefit from the stronger autonomous floor.
- Blockers: none.
- Next slice: add the automation prompt helper that emits task-only recurring prompt variants from existing Campfire state.
