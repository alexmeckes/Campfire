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

## 2026-03-14 milestone-024 course-correction

- Course correction: the user clarified that they want a true manual-stop autonomous run, not just a stronger floor on a still-bounded rolling session.
- Changed: deferred the automation-helper implementation again, then rewired the rolling contract, helper, resume guidance, and docs around an explicit `run_style: until_stopped`.
- Validation: reviewed the execution policy and confirmed the remaining internal stop causes were the bounded runtime budget, milestone cap, and reframe cap.
- Blockers: none.
- Next slice: add deterministic verification for the until-stopped rolling style and queue the self-hosted task into that mode.

## 2026-03-14 milestone-024

- Changed: updated `enable_rolling_mode.sh`, `init_task.sh`, `resume_task.sh`, the task-state contract, worker/framer/evaluator guidance, and README so Campfire can declare `run_style: until_stopped` with no internal runtime budget or milestone cap.
- Changed: added `skills/task-handoff-state/scripts/verify_until_stopped_mode.sh`, wired it into `scripts/verify_repo.sh`, and refreshed Campfire's own task-state/runbook guidance to use the new manual-stop style.
- Validation: ran `./skills/task-handoff-state/scripts/verify_until_stopped_mode.sh`, `./skills/task-handoff-state/scripts/verify_enable_rolling_mode.sh`, `./skills/task-handoff-state/scripts/verify_autonomous_floor.sh`, `./scripts/verify_repo.sh`, and `./scripts/resume_task.sh improve-campfire` successfully.
- Blockers: none.
- Next slice: resume the deferred automation-helper backlog from the now manual-stop self-hosted queue.

## 2026-03-14 milestone-024

- Changed: added `skills/task-handoff-state/scripts/automation_prompt_helper.sh` so Campfire can emit task-only `rolling_resume`, `verifier_sweep`, and `backlog_refresh` prompt variants directly from existing task state.
- Validation: ran `./skills/task-handoff-state/scripts/automation_prompt_helper.sh --root /Users/alexmeckes/Downloads/Campfire improve-campfire` and confirmed the prompts target `.autonomous/improve-campfire/` without embedding schedule or workspace settings.
- Blockers: none.
- Next slice: add deterministic verification for bounded and `until_stopped` automation prompt helper output.

## 2026-03-14 milestone-025

- Changed: added `skills/task-handoff-state/scripts/verify_automation_prompt_helper.sh` and wired it into `scripts/verify_repo.sh`.
- Validation: ran `./skills/task-handoff-state/scripts/verify_automation_prompt_helper.sh` successfully.
- Blockers: none.
- Next slice: document the helper in the generic task-state docs and example automation guidance.

## 2026-03-14 milestone-026

- Changed: documented the helper in `README.md`, `skills/task-handoff-state/SKILL.md`, `skills/task-handoff-state/references/automation-patterns.md`, `examples/basic-workspace/AGENTS.md`, and `examples/basic-workspace/.autonomous/rolling-task/findings/automation-ready.md`.
- Validation: reviewed the helper-related docs together and confirmed they point to generated prompt variants instead of copied examples.
- Blockers: none.
- Next slice: surface the helper output directly from `resume_task.sh` for rolling tasks.

## 2026-03-14 milestone-027

- Changed: updated `skills/task-handoff-state/scripts/resume_task.sh` so rolling tasks now print automation prompt variants from `automation_prompt_helper.sh` after the main resume prompt.
- Validation: ran `./scripts/resume_task.sh improve-campfire` successfully and confirmed the automation prompt section appeared.
- Blockers: none.
- Next slice: add deterministic verification for the new resume automation-guidance output.

## 2026-03-14 milestone-028

- Changed: added `skills/task-handoff-state/scripts/verify_resume_automation_prompt_guidance.sh` and recorded the independent evaluator note in `findings/milestone-028-evaluation.md`.
- Changed: expanded `scripts/verify_repo.sh` to cover the new helper and resume-guidance verifiers, then updated the Campfire runbook around the completed automation-helper backlog.
- Validation: ran `./skills/task-handoff-state/scripts/verify_resume_automation_prompt_guidance.sh` and `./scripts/verify_repo.sh` successfully.
- Blockers: none.
- Next slice: use one bounded reframe to queue the next backlog around automation proposal metadata.

## 2026-03-14 milestone-029 framing

- Auto reframe: after the automation-helper backlog validated, the next bounded planning slice reframed the queue around automation proposal metadata for recurring Codex App runs.
- Changed: recorded the new backlog in `plan.md`, `runbook.md`, `handoff.md`, `checkpoints.json`, and `findings/milestone-029-automation-proposal-backlog.md`.
- Validation: reviewed the completed helper/evaluator artifacts and confirmed the next leverage point is automation proposal metadata rather than more prompt-body duplication.
- Blockers: none.
- Next slice: add an automation proposal helper that emits a suggested automation name and task-only prompt from existing Campfire state.

## 2026-03-15 milestone-029 course-correction

- Course correction: a fresh-thread test showed that a missing continue target in the wrong workspace could still be reframed into a brand-new task, which is more urgent than automation proposal metadata.
- Changed: deferred the automation-proposal backlog, recorded the reason in `findings/milestone-029-missing-resume-course-correction.md`, and rewrote the active backlog around missing-resume guardrails.
- Validation: reviewed the fresh-thread transcript and confirmed the root issue was not runtime persistence but a missing resume target being treated like a new-task framing opportunity.
- Blockers: none.
- Next slice: harden `resume_task.sh` and the core Campfire skills so continue/resume requests stop on missing task state.

## 2026-03-15 milestone-029

- Changed: updated `skills/task-handoff-state/scripts/resume_task.sh`, `skills/task-handoff-state/SKILL.md`, `skills/task-framer/SKILL.md`, `skills/long-horizon-worker/SKILL.md`, and `skills/task-handoff-state/references/task-state-contract.md` so missing continue targets are treated as a hard stop instead of a bootstrap signal.
- Validation: ran `./skills/task-handoff-state/scripts/verify_missing_resume_guardrail.sh` successfully after wiring the new script guidance and stop behavior.
- Blockers: none.
- Next slice: wire the new guardrail into repo verification and user-facing docs/example guidance.

## 2026-03-15 milestone-030

- Changed: added `skills/task-handoff-state/scripts/verify_missing_resume_guardrail.sh` and wired it into `scripts/verify_repo.sh`.
- Validation: ran `./scripts/verify_repo.sh` successfully with the new guardrail verifier included.
- Blockers: none.
- Next slice: update README and example guidance so missing resume targets are clearly treated as stop conditions.

## 2026-03-15 milestone-031

- Changed: documented the missing-resume guardrail in `README.md`, `examples/basic-workspace/AGENTS.md`, and the task-state skill quick start, then recorded the evaluator note in `findings/milestone-031-evaluation.md`.
- Validation: reviewed the updated docs and the passing guardrail verifier to confirm the create-vs-resume distinction is now explicit.
- Blockers: none.
- Next slice: use one bounded reframe to restore the deferred automation-proposal backlog behind the now-validated guardrail.

## 2026-03-15 milestone-034 framing

- Auto reframe: after the missing-resume guardrail validated, the next bounded planning slice restored the deferred automation-proposal work as the next backlog.
- Changed: recorded the refreshed backlog in `plan.md`, `runbook.md`, `handoff.md`, `checkpoints.json`, and `findings/milestone-034-automation-proposal-backlog.md`.
- Validation: reviewed the guardrail evaluation and confirmed the automation-proposal backlog is still the next safe generic improvement area.
- Blockers: none.
- Next slice: add an automation proposal helper that emits a suggested automation name and task-only prompt from existing Campfire state.

## 2026-03-15 milestone-039 framing

- Course correction: reviewing `badlogic/pi-mono/packages/coding-agent` suggested a higher-leverage next backlog than the deferred automation-proposal helper queue.
- Changed: recorded a new bounded backlog in `findings/milestone-039-pi-inspired-backlog.md` focused on prompt templates, steering-versus-follow-up task guidance, packageable generated skills, and session-lineage metadata.
- Changed: rewrote `plan.md`, `handoff.md`, `checkpoints.json`, and `artifacts.json` so the self-hosted task now resumes on `milestone-039` instead of the stale automation-proposal backlog.
- Validation: reviewed the Pi-inspired backlog against the current Campfire control-plane, generated-skill, and benchmark docs and confirmed the five milestones remain single-agent, local-first, and dependency-safe.
- Blockers: none.
- Next slice: add a prompt-template layer for canonical Campfire operator flows, then verify and document it before moving into steering queues and session lineage.

## 2026-03-16 milestone-039

- Changed: added `skills/task-handoff-state/templates/prompt_templates.json`, `skills/task-handoff-state/scripts/prompt_template_helper.sh`, and the repo/example wrappers so Campfire now has one small prompt-template surface for canonical operator flows.
- Changed: rewired `resume_task.sh`, `automation_prompt_helper.sh`, `start_slice.sh`, `enable_rolling_mode.sh`, `init_task.sh`, `bootstrap_task.sh`, and `promote_improvement.sh` to render prompts from the shared helper instead of repeating prompt prose inline.
- Changed: documented the prompt-template layer in `README.md`, `skills/task-handoff-state/SKILL.md`, `skills/task-retrospector/SKILL.md`, `docs/campfire-bench.md`, `benchmarks/campfire-bench/README.md`, and `docs/campfire-v3-control-plane.md`.
- Validation: ran direct helper checks for resume, retrospective, benchmark, and improvement-promotion prompts, then ran `./examples/basic-workspace/scripts/verify_harness.sh` and `./scripts/verify_repo.sh`.
- Blockers: none.
- Next slice: auto-advance into milestone-040 and add deterministic verifier coverage for the new prompt-template helper.

## 2026-03-16 milestone-040 framing

- Auto advance: after `milestone-039` validated, the rolling queue promoted `milestone-040` to the active milestone without pausing the unattended run.
- Changed: recorded the coverage target in `findings/milestone-040-prompt-template-coverage.md` and refreshed the task state so the next slice focuses on verifier wiring rather than more prompt-surface redesign.
- Validation: reviewed the new prompt-template helper, the example wrapper flow, and the existing repo verifier to confirm the next safe work is deterministic coverage plus repo wiring.
- Blockers: none.
- Next slice: add `verify_prompt_template_helper.sh`, wire it into `scripts/verify_repo.sh`, and keep the example wrapper flow green.

## 2026-03-16 milestone-040

- Changed: added `skills/task-handoff-state/scripts/verify_prompt_template_helper.sh` to cover task-bootstrap, resume, retrospective, benchmark, and improvement-promotion prompt rendering from stable task state.
- Changed: wired the new verifier into `scripts/verify_repo.sh`, tightened the example wrapper harness to invoke `prompt_template_helper.sh` directly in the temp workspace, and updated the task-state skill quick start plus runbook with the new coverage command.
- Validation: ran `./skills/task-handoff-state/scripts/verify_prompt_template_helper.sh`, `./examples/basic-workspace/scripts/verify_harness.sh`, and `./scripts/verify_repo.sh` successfully.
- Blockers: none.
- Next slice: auto-advance into milestone-041 and add a lightweight steering-versus-follow-up queue model in the control plane and generated context surfaces.

## 2026-03-16 milestone-041 framing

- Auto advance: after `milestone-040` validated, the rolling queue promoted `milestone-041` to the active milestone without pausing the unattended run.
- Changed: recorded the steering-versus-follow-up scope in `findings/milestone-041-steering-follow-up-queue.md` so the next slice can stay narrow: guidance visibility, not scheduler behavior.
- Validation: reviewed the current SQL control-plane schema, task-state contract, and generated context builders to confirm the next safe work is a small guidance-entry surface and projection update.
- Blockers: none.
- Next slice: add a small guidance-entry surface in the SQL control plane and task projections, then expose interrupt-now versus next-boundary guidance without inventing a scheduler.

## 2026-03-16 milestone-041

- Changed: added `guidance_entries` support plus guidance normalization in `skills/task-handoff-state/scripts/campfire_sql.py` so interrupt-now and next-boundary guidance persist in the SQL control plane and generated projections.
- Changed: added `skills/task-handoff-state/scripts/queue_guidance.sh` and the repo/example wrappers so operators can queue guidance without hand-editing `checkpoints.json`.
- Changed: added `skills/task-handoff-state/scripts/verify_guidance_queue.sh`, wired it into `scripts/verify_repo.sh`, tightened the example wrapper harness, and documented the guidance surface in `README.md`, `skills/task-handoff-state/SKILL.md`, `skills/task-handoff-state/references/task-state-contract.md`, and `docs/campfire-v3-control-plane.md`.
- Validation: ran `./skills/task-handoff-state/scripts/verify_guidance_queue.sh`, `CAMPFIRE_SKILLS_ROOT=\"/Users/alexmeckes/Downloads/Campfire/skills\" ./examples/basic-workspace/scripts/verify_harness.sh`, and `./scripts/verify_repo.sh` successfully.
- Blockers: none.
- Next slice: auto-advance into milestone-042, then add a standardized skill inventory and generated-skill discovery surface before queue depth falls further.

## 2026-03-16 milestone-042 framing

- Auto advance: after `milestone-041` validated, the rolling queue promoted `milestone-042` to the active milestone without pausing the unattended run.
- Changed: recorded the discovery-surface scope in `findings/milestone-042-skill-discovery-surfaces.md` so the next slice focuses on a packageable skill inventory instead of a larger generated-skill runtime.
- Validation: reviewed `docs/campfire-generated-skills.md`, the current installer flow, and the existing context projections to confirm the next safe work is a standardized discovery manifest plus deterministic coverage.
- Blockers: none.
- Next slice: add a packageable skill inventory and generated-skill discovery surface, then validate discovered core, repo-local, and task-local skill surfaces with a dedicated verifier.

## 2026-03-16 milestone-042

- Changed: extended `skills/task-handoff-state/scripts/campfire_sql.py` so `refresh_registry.sh` now renders `.campfire/skill_inventory.json` and exposes discovery metadata through `project_context.json` and `task_context.json`.
- Changed: added `skills/task-handoff-state/scripts/verify_skill_inventory.sh`, wired it into `scripts/verify_repo.sh`, and updated the SQL control-plane verifier to require the generated skill inventory surface.
- Changed: documented the packageable discovery manifest in `README.md`, `skills/task-handoff-state/SKILL.md`, `skills/task-handoff-state/references/task-state-contract.md`, `docs/campfire-v3-control-plane.md`, and `docs/campfire-generated-skills.md`.
- Validation: ran `./skills/task-handoff-state/scripts/verify_skill_inventory.sh`, `./skills/task-handoff-state/scripts/verify_sql_control_plane.sh`, `./skills/task-handoff-state/scripts/verify_guidance_queue.sh`, and `./scripts/verify_repo.sh` successfully.
- Blockers: none.
- Next slice: auto-advance into milestone-043 before the queue empties, then add stable run identifiers and parent-child lineage metadata.

## 2026-03-16 milestone-043 framing

- Auto advance: after `milestone-042` validated, the rolling queue promoted `milestone-043` to the active milestone without pausing the unattended run.
- Changed: recorded the session-lineage scope in `findings/milestone-043-session-lineage.md` so the next slice focuses on stable run identifiers, parent-child lineage, and source-run linkage.
- Validation: reviewed the session table, current `record_improvement_candidate.sh` `source_run_id` path, and benchmark result schema to confirm the next safe work is lineage metadata rather than a new benchmark runtime.
- Blockers: none.
- Next slice: add stable run identifiers and parent-child session lineage, then validate retry-style lineage, branch labels, and source-run linkage with a dedicated verifier.

## 2026-03-16 milestone-043

- Changed: extended `skills/task-handoff-state/scripts/start_slice.sh` so new slices can carry stable `run_id` values plus optional `parent_run_id`, `lineage_kind`, and `branch_label` metadata.
- Changed: extended `skills/task-handoff-state/scripts/campfire_sql.py`, `doctor_task.sh`, and generated context surfaces so sessions persist and expose lineage metadata across retries and benchmark repro branches.
- Changed: added `skills/task-handoff-state/scripts/verify_session_lineage.sh`, wired it into `scripts/verify_repo.sh`, and documented the new run-id and lineage contract in the task-state, control-plane, benchmark, and task-state skill docs.
- Validation: ran `./skills/task-handoff-state/scripts/verify_session_lineage.sh`, `./skills/task-handoff-state/scripts/verify_task_lifecycle.sh`, `./skills/task-handoff-state/scripts/verify_start_slice.sh`, `./skills/task-handoff-state/scripts/verify_complete_slice.sh`, `./skills/task-handoff-state/scripts/verify_improvement_flow.sh`, and `./scripts/verify_repo.sh` successfully.
- Blockers: none.
- Next slice: spend one bounded reframe replenishing the rolling queue around generated-skill drafting, then auto-advance into the first drafted-skill implementation slice.

## 2026-03-16 milestone-044 framing

- Auto reframe: queue depth reached zero after `milestone-043` validated, so the run spent one bounded planning slice replenishing the next backlog around generated-skill drafting and the deferred automation-proposal helper.
- Changed: recorded the replenished backlog in `findings/milestone-044-generated-skill-drafting-backlog.md` and refreshed `plan.md`, `checkpoints.json`, `handoff.md`, `progress.md`, and `artifacts.json` so the next unattended slice resumes on generated-skill drafting instead of stopping on an empty queue.
- Validation: reviewed the generated-skill policy, improvement backlog surface, and new packageable discovery manifest to confirm the refreshed queue remains dependency-safe and single-agent.
- Blockers: none.
- Next slice: add a helper that drafts generated skills from structured improvement candidates.

## 2026-03-16 milestone-044

- Changed: added `skills/task-handoff-state/scripts/draft_generated_skill.sh` plus the repo-local wrapper `scripts/draft_generated_skill.sh` so structured `skill_candidate` entries can become repo-local or task-local draft skill scaffolds mechanically.
- Changed: refreshed registry output after draft creation so `.campfire/skill_inventory.json`, `.campfire/project_context.json`, and task-local `task_context.json` expose the new draft skill surfaces immediately.
- Validation: ran a manual smoke flow in a temp workspace that recorded candidates, drafted repo-local and task-local skills, confirmed the generated files existed, and confirmed inventory discovery reported the drafted repo-local skill surface.
- Blockers: none.
- Next slice: auto-advance into milestone-045 and replace the manual smoke check with deterministic verifier and example-wrapper coverage.

## 2026-03-16 milestone-045 framing

- Auto advance: after `milestone-044` validated, the rolling queue promoted `milestone-045` to the active milestone without pausing the unattended run.
- Changed: recorded the generated-skill coverage target in `findings/milestone-045-generated-skill-coverage.md` and refreshed handoff state so the next slice stays narrow: deterministic verifier wiring plus example wrapper coverage.
- Validation: reviewed the new draft helper, existing example wrappers, and repo verifier to confirm the next safe work is coverage, not another control-plane expansion.
- Blockers: none.
- Next slice: add `verify_draft_generated_skill.sh`, wire it into `scripts/verify_repo.sh`, and make the example harness prove drafted skills appear in the generated inventory surfaces.

## 2026-03-16

- Completed `milestone-050` / `slice-050-resume-automation-proposal-verifier` with status `validated`.
- Summary: Validated rolling resume automation proposal guidance through the dedicated verifier and the repo suite.
- Next step: Decision boundary: choose whether Campfire should stay proposal-only, add generic schedule-input scaffolds, or add Codex App-specific automation instantiation support.

## 2026-03-16 milestone-050 retrospective

- Retrospective: the automation-proposal backlog completed cleanly, and the reusable rollout ladder was helper -> verifier coverage -> docs -> live resume surfacing -> resume-surface verifier.
- Decision boundary: the next automation surface now depends on a product choice between generic schedule-input scaffolds and Codex App-specific automation instantiation support.
- Next action: resolve that boundary before framing a new automation backlog.

- Started `milestone-050` / `slice-050-resume-automation-proposal-verifier`.
- Active slice: Verify rolling resume automation proposal guidance
- Validation target: Add a dedicated verifier for rolling resume automation proposal metadata and wire it into the repo suite.

- Completed `milestone-049` / `slice-049-resume-automation-proposals` with status `validated`.
- Summary: Validated rolling resume automation proposal guidance through direct resume output inspection and helper parity.
- Next step: Auto-advance into milestone-050 and add a dedicated verifier for the new resume-task proposal guidance.

- Started `milestone-049` / `slice-049-resume-automation-proposals`.
- Active slice: Surface automation proposal guidance in rolling resume output
- Validation target: Update rolling resume output to call the automation proposal helper without duplicating proposal logic.

- Completed `milestone-048` / `slice-048-automation-proposal-docs` with status `validated`.
- Summary: Validated automation proposal documentation across README, task-state quick start, example guidance, and the task runbook.
- Next step: Auto-advance into milestone-049 and surface automation proposal guidance from rolling resume output.

- Started `milestone-048` / `slice-048-automation-proposal-docs`.
- Active slice: Document automation proposal helper usage
- Validation target: Update README, task-state skill docs, and example guidance for automation proposal metadata.

- Completed `milestone-047` / `slice-047-automation-proposal-coverage` with status `validated`.
- Summary: Validated automation proposal coverage through the dedicated verifier, example wrapper flow, and the repo suite.
- Next step: Auto-advance into milestone-048 and document when to use automation proposal metadata across README and example guidance.

- Started `milestone-047` / `slice-047-automation-proposal-coverage`.
- Active slice: Verify automation proposal helper and example coverage
- Validation target: Add a dedicated automation proposal verifier, example wrapper flow, and repo-suite wiring.

- Completed `milestone-046` / `slice-046-automation-proposal-helper` with status `validated`.
- Summary: Validated automation proposal helper metadata through direct helper output and repo-wrapper JSON assertions.
- Next step: Auto-advance into milestone-047 and add deterministic verifier plus example-wrapper coverage for automation proposals.

- Started `milestone-046` / `slice-046-automation-proposal-helper`.
- Active slice: Add schedule-agnostic automation proposal helper metadata
- Validation target: Implement automation proposal helper and repo wrapper using task context plus prompt-template output.

- Completed `milestone-045` / `slice-045-draft-skill-coverage` with status `validated`.
- Summary: Validated generated-skill draft coverage through dedicated verifier, example wrapper flow, and the repo suite.
- Next step: Auto-advance into milestone-046 and implement schedule-agnostic automation proposal helper metadata on top of prompt templates and task context.
