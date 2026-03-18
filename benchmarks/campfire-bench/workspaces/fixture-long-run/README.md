# Fixture Long Run Workspace

This workspace is the canonical `fixture-long-run` benchmark project for CampfireBench.

It is intentionally neutral:

- no product-specific domain
- no stale consumer-repo objective
- one seeded long-horizon task under `.autonomous/fixture-long-run/`
- local wrapper scripts and a minimal Claude adapter copied from the example workspace

Use this workspace when you want to measure Campfire’s long-run mechanics rather than a product repo’s domain complexity.

## Included Surfaces

- `AGENTS.md` for benchmark-specific execution rules
- `benchmark/` for the source-of-truth benchmark brief, checklist, and inventory
- `.autonomous/fixture-long-run/` for the seeded rolling task
- `.claude/` for adapter-parity or hook-level experiments
- `scripts/` for thin local wrappers plus `verify_fixture_workspace.sh`

## Local Verification

Run the workspace verifier:

```bash
CAMPFIRE_SKILLS_ROOT=/abs/path/to/Campfire/skills ./scripts/verify_fixture_workspace.sh
```

That checks:

- the neutral benchmark files exist
- the seeded task state is coherent
- `resume_task.sh` and `doctor_task.sh` work from this workspace

## Benchmark Intent

This workspace is designed to force a long-horizon run to exercise:

- rolling queue consumption
- explicit validation boundaries
- queue replenish and reframe
- one deliberate decision-boundary stop

The benchmark result should say something about Campfire itself, not about a product milestone.
