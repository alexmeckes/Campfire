# Runbook

## Workspace

- Root: /Users/alexmeckes/Downloads/Campfire
- Task: improve-campfire

## Boot / Setup

- Optional install into ~/.codex/skills: ./scripts/install_skills.sh
- Repo verification: ./scripts/verify_repo.sh
- Lifecycle verification: ./skills/task-handoff-state/scripts/verify_task_lifecycle.sh
- Blocked/retry verification: ./skills/task-handoff-state/scripts/verify_blocked_retry.sh
- Course-correction verification: ./skills/task-handoff-state/scripts/verify_course_correction.sh
- Task-evaluation verification: ./skills/task-handoff-state/scripts/verify_task_evaluation.sh
- Rolling-execution verification: ./skills/task-handoff-state/scripts/verify_rolling_execution.sh
- Review framing skill: ./skills/task-framer/SKILL.md
- Review correction skill: ./skills/course-corrector/SKILL.md
- Review evaluator skill: ./skills/task-evaluator/SKILL.md
- Review rolling backlog brief: .autonomous/improve-campfire/findings/milestone-006-rolling-backlog.md
- Review task brief: .autonomous/improve-campfire/findings/milestone-004-brief.md

## Validation

- Primary: ./scripts/verify_repo.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_task_lifecycle.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_blocked_retry.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_course_correction.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_task_evaluation.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_rolling_execution.sh
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
- Planning is allowed, but keep each rolling planning slice to about 10 minutes before shipping code
