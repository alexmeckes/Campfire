# Milestone 039 Evaluation

## Evaluated Milestone

- `milestone-039` - Add a prompt-template layer for canonical Campfire operator flows

## Acceptance Criteria

### 1. Campfire provides a small prompt-template surface for canonical operator flows instead of relying on large hand-written markdown blocks

Pass.

Evidence:

- Added `skills/task-handoff-state/templates/prompt_templates.json` as the canonical template source.
- Added `skills/task-handoff-state/scripts/prompt_template_helper.sh` plus the repo wrapper `scripts/prompt_template_helper.sh`.
- Rewired `resume_task.sh`, `automation_prompt_helper.sh`, `start_slice.sh`, `enable_rolling_mode.sh`, `init_task.sh`, `bootstrap_task.sh`, and `promote_improvement.sh` to render prompts from the shared helper instead of repeating inline prompt prose.

### 2. Canonical templates exist for resume, retrospective, benchmark, and improvement-promotion flows and stay task-only plus reusable

Pass.

Evidence:

- Direct rendering checks passed for:
  - `./scripts/prompt_template_helper.sh --task-slug improve-campfire resume`
  - `./scripts/prompt_template_helper.sh --task-slug improve-campfire retrospective`
  - `./scripts/prompt_template_helper.sh benchmark`
  - `./scripts/prompt_template_helper.sh --task-slug improve-campfire --candidate-id slice-start-guard improvement_promotion`
- Added `skills/task-handoff-state/references/prompt-templates.md` and linked it from the task-state skill and top-level README.

### 3. The template layer stays compatible with the current skill stack and local-first control-plane model

Pass.

Evidence:

- `./examples/basic-workspace/scripts/verify_harness.sh`
- `./scripts/verify_repo.sh`
- Updated `docs/campfire-v3-control-plane.md`, `docs/campfire-bench.md`, `benchmarks/campfire-bench/README.md`, `skills/task-handoff-state/SKILL.md`, and `skills/task-retrospector/SKILL.md` so the new prompt surface stays aligned with Campfire's existing skill and control-plane model.

## Result

- `milestone-039` is validated.
- Rolling execution can auto-advance to `milestone-040`.
