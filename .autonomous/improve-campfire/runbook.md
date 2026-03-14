# Runbook

## Workspace

- Root: /Users/alexmeckes/Downloads/Campfire
- Task: improve-campfire

## Boot / Setup

- Optional install into ~/.codex/skills: ./scripts/install_skills.sh
- Rolling-mode helper: ./scripts/enable_rolling_mode.sh <task-slug> --queue "milestone-id:Milestone title"
- Manual-stop rolling helper: ./scripts/enable_rolling_mode.sh --until-stopped <task-slug> --queue "milestone-id:Milestone title"
- Automation prompt helper: ./skills/task-handoff-state/scripts/automation_prompt_helper.sh --root /Users/alexmeckes/Downloads/Campfire <task-slug>
- Repo verification: ./scripts/verify_repo.sh
- Lifecycle verification: ./skills/task-handoff-state/scripts/verify_task_lifecycle.sh
- Blocked/retry verification: ./skills/task-handoff-state/scripts/verify_blocked_retry.sh
- Course-correction verification: ./skills/task-handoff-state/scripts/verify_course_correction.sh
- Task-evaluation verification: ./skills/task-handoff-state/scripts/verify_task_evaluation.sh
- Rolling-execution verification: ./skills/task-handoff-state/scripts/verify_rolling_execution.sh
- Rolling reframe verification: ./skills/task-handoff-state/scripts/verify_rolling_reframe.sh
- Rolling-mode helper verification: ./skills/task-handoff-state/scripts/verify_enable_rolling_mode.sh
- Missing-resume guardrail verification: ./skills/task-handoff-state/scripts/verify_missing_resume_guardrail.sh
- Autonomous-floor verification: ./skills/task-handoff-state/scripts/verify_autonomous_floor.sh
- Until-stopped verification: ./skills/task-handoff-state/scripts/verify_until_stopped_mode.sh
- Rolling budget-limit verification: ./skills/task-handoff-state/scripts/verify_budget_limit.sh
- Rolling waiting-on-decision verification: ./skills/task-handoff-state/scripts/verify_waiting_on_decision.sh
- Automation-pattern verification: ./skills/task-handoff-state/scripts/verify_automation_patterns.sh
- Automation prompt helper verification: ./skills/task-handoff-state/scripts/verify_automation_prompt_helper.sh
- Resume automation-guidance verification: ./skills/task-handoff-state/scripts/verify_resume_automation_prompt_guidance.sh
- Review framing skill: ./skills/task-framer/SKILL.md
- Review correction skill: ./skills/course-corrector/SKILL.md
- Review evaluator skill: ./skills/task-evaluator/SKILL.md
- Review rolling backlog brief: .autonomous/improve-campfire/findings/milestone-006-rolling-backlog.md
- Review task brief: .autonomous/improve-campfire/findings/milestone-004-brief.md
- Review stop-condition brief: .autonomous/improve-campfire/findings/milestone-009-rolling-stop-conditions.md
- Review worktree backlog brief: .autonomous/improve-campfire/findings/milestone-015-worktree-backlog.md
- Review automation backlog brief: .autonomous/improve-campfire/findings/milestone-018-automation-backlog.md
- Review autonomy-floor correction note: .autonomous/improve-campfire/findings/milestone-021-autonomy-floor-course-correction.md
- Review autonomy-floor evaluation: .autonomous/improve-campfire/findings/milestone-023-evaluation.md
- Review automation-helper backlog brief: .autonomous/improve-campfire/findings/milestone-024-automation-helper-backlog.md
- Review automation-helper evaluation: .autonomous/improve-campfire/findings/milestone-028-evaluation.md
- Review missing-resume course-correction note: .autonomous/improve-campfire/findings/milestone-029-missing-resume-course-correction.md
- Review missing-resume evaluation: .autonomous/improve-campfire/findings/milestone-031-evaluation.md
- Review automation proposal backlog brief: .autonomous/improve-campfire/findings/milestone-029-automation-proposal-backlog.md
- Review refreshed automation proposal backlog brief: .autonomous/improve-campfire/findings/milestone-034-automation-proposal-backlog.md
- Review automation patterns reference: skills/task-handoff-state/references/automation-patterns.md

## Validation

- Primary: ./scripts/verify_repo.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_task_lifecycle.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_blocked_retry.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_course_correction.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_task_evaluation.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_rolling_execution.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_rolling_reframe.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_enable_rolling_mode.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_missing_resume_guardrail.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_autonomous_floor.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_until_stopped_mode.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_budget_limit.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_waiting_on_decision.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_automation_patterns.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_automation_prompt_helper.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_resume_automation_prompt_guidance.sh
- Secondary: inspect the task-evaluator skill, reference docs, installer wiring, and repo verifier wiring
- Record new verifier scripts in artifacts.json when they become part of the harness

## Observability

- Logs: .autonomous/improve-campfire/logs/
- Artifacts: .autonomous/improve-campfire/artifacts/
- Findings: .autonomous/improve-campfire/findings/

## Notes

- Repo-local AGENTS.md defines self-hosting priorities
- Prefer improvements that strengthen portability, verifiers, or resume semantics
- Unattended run target: about 2 hours total
- Manual-stop unattended runs may continue without an internal budget or milestone cap until a blocker, decision boundary, safe-work exhaustion, or an external pause occurs
- Planning is allowed, but keep each rolling planning slice to about 10 minutes before shipping code
- When the queued rolling backlog is exhausted, stop and frame the next backlog instead of inventing one silently
- If queue replenishment is enabled and queue depth drops below the configured threshold while budget remains, or no internal budget is configured, spend one bounded planning slice to refill the queue before stopping
- In `run_style: until_stopped`, treat zero budget and zero caps as intentional: keep queue replenishment active until the run is externally paused or runs out of safe work
- A rolling pause on `budget_limit` or `waiting_on_decision` should preserve the active milestone and remaining queued milestones for the next run
- For autonomous runs, `manual_pause` should be treated as external-only and not chosen before the minimum runtime and milestone floor are met
- For git repos, prefer optional worktree-backed setup only when it improves long-horizon isolation without weakening non-git portability
- For recurring Codex App automations, prefer reusable prompt patterns and explicit workspace guidance over project-specific magic
- For continue/resume requests, treat a missing named task slug as a hard stop and confirm the workspace before creating anything new
