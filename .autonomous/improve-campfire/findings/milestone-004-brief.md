# Milestone-004 Brief

## Goal

Add the missing `task-evaluator` layer to Campfire so the harness covers framing, execution, course correction, state, and explicit evaluation.

## Why This Is Next

- Campfire can frame, execute, re-plan, and persist state, but it still lacks a generic evaluator role.
- An evaluator closes the loop for long-horizon work by checking whether a milestone is actually done instead of trusting the worker's own summary.
- This is a good unattended-run target because it has a clear shape, repo-local deliverables, and strong validation through `./scripts/verify_repo.sh`.

## Time Budget

- Total target: about 2 hours
- Planning budget: up to 15 minutes
- If the scope still feels vague after one bounded planning slice, stop and record a blocker instead of drifting

## Expected Deliverables

- `skills/task-evaluator/SKILL.md`
- `skills/task-evaluator/agents/openai.yaml`
- `skills/task-evaluator/references/` note if needed
- installer wiring in `scripts/install_skills.sh`
- repo verification wiring in `scripts/verify_repo.sh`
- README updates explaining where evaluation fits in Campfire
- task-state updates in `.autonomous/improve-campfire/`

## Suggested Slice Order

1. Confirm evaluator scope and acceptance criteria against the existing four-skill model.
2. Add the `task-evaluator` skill definition and agent metadata.
3. Add any minimal evaluator reference doc needed to keep the skill concrete.
4. Wire the new skill into install and verification scripts.
5. Update README and any task-state-contract language needed to place evaluation in the loop.
6. Run `./scripts/verify_repo.sh`.
7. Update task state with evidence and stop only on milestone validation or a real blocker.

## Acceptance Criteria

- Campfire now includes a generic evaluator skill.
- The evaluator fits cleanly into the existing README and task model.
- The repo installer and verifier know about the evaluator layer.
- The run ends with updated task state and validation evidence.
