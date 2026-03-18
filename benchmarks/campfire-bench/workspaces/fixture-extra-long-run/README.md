# Fixture Extra Long Run Workspace

This workspace is the canonical `fixture-extra-long-run` benchmark project for CampfireBench.

It is intentionally neutral and longer-running than the long fixture:

- no product-specific domain
- one seeded extra-long task under `.autonomous/fixture-extra-long-run/`
- a larger benchmark inventory with more milestones
- seeded blocker and decision-boundary artifacts

Use this workspace when you want to test whether Campfire stays coherent over hours rather than over a shorter rolling run.

## Included Surfaces

- `AGENTS.md` for benchmark-specific execution rules
- `benchmark/` for the source-of-truth benchmark brief, checklist, blocker, decision, and inventory
- `.autonomous/fixture-extra-long-run/` for the seeded rolling task
- `.claude/` for adapter or hook experiments
- `scripts/` for thin local wrappers plus `verify_fixture_workspace.sh`

## Local Verification

Run the workspace verifier:

```bash
CAMPFIRE_SKILLS_ROOT=/abs/path/to/Campfire/skills ./scripts/verify_fixture_workspace.sh
```

That checks:

- the benchmark source files exist
- the seeded blocker and decision files are present
- the seeded task state is coherent
- `resume_task.sh` and `doctor_task.sh` work from this workspace
