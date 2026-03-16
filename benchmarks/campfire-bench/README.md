# CampfireBench

This folder contains the initial benchmark scaffold for Campfire.

The benchmark is intentionally lightweight:

- scenario definitions live in `scenarios/`
- sample result files live in `fixtures/results/`
- `scripts/run_campfire_bench.py` validates scenarios and scores result files

## Commands

Validate the bundled scenarios:

```bash
python3 scripts/run_campfire_bench.py --root . --validate-only
```

Score the bundled sample results:

```bash
python3 scripts/run_campfire_bench.py --root . --results-dir benchmarks/campfire-bench/fixtures/results
```

Print the canonical benchmark-review prompt:

```bash
./scripts/prompt_template_helper.sh benchmark
```

## Scenario Categories

- `synthetic_lifecycle`
- `repo_medium`
- `long_horizon`

## Current Goal

The current scaffold is not a full autonomous evaluator yet. It gives Campfire:

- a benchmark contract
- starter scenarios
- a consistent scoring model
- a way to measure orchestration overhead explicitly
