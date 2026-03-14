# Runbook

## Workspace

- Root: /Users/alexmeckes/Downloads/Campfire
- Task: improve-campfire

## Boot / Setup

- Optional install into ~/.codex/skills: ./scripts/install_skills.sh
- Repo verification: ./scripts/verify_repo.sh
- Lifecycle verification: ./skills/task-handoff-state/scripts/verify_task_lifecycle.sh
- Blocked/retry verification: ./skills/task-handoff-state/scripts/verify_blocked_retry.sh
- Review framing skill: ./skills/task-framer/SKILL.md
- Review correction skill: ./skills/course-corrector/SKILL.md

## Validation

- Primary: ./scripts/verify_repo.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_task_lifecycle.sh
- Secondary: ./skills/task-handoff-state/scripts/verify_blocked_retry.sh
- Secondary: inspect skills/task-framer and skills/course-corrector plus installer wiring
- Record new verifier scripts in artifacts.json when they become part of the harness

## Observability

- Logs: .autonomous/improve-campfire/logs/
- Artifacts: .autonomous/improve-campfire/artifacts/
- Findings: .autonomous/improve-campfire/findings/

## Notes

- Repo-local AGENTS.md defines self-hosting priorities
- Prefer improvements that strengthen portability, verifiers, or resume semantics
