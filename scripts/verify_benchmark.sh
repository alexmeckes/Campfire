#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT_DIR/scripts/run_campfire_bench.py"
BENCH_ROOT="$ROOT_DIR/benchmarks/campfire-bench"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_contains() {
  local path="$1"
  local pattern="$2"
  if ! /usr/bin/grep -Fq -- "$pattern" "$path"; then
    fail "Expected pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$ROOT_DIR/scripts/verify_benchmark.sh"
python3 -m py_compile "$RUNNER"

echo "== Scenario validation =="
python3 "$RUNNER" --root "$ROOT_DIR" --validate-only >/tmp/campfire_bench_validate.out
expect_contains /tmp/campfire_bench_validate.out '"scenario_count": 10'
expect_contains /tmp/campfire_bench_validate.out '"resume-after-interrupt"'
expect_contains /tmp/campfire_bench_validate.out '"adapter-parity"'
expect_contains /tmp/campfire_bench_validate.out '"fixture-extra-long-run"'
expect_contains /tmp/campfire_bench_validate.out '"fixture-long-run"'
expect_contains /tmp/campfire_bench_validate.out '"long_horizon"'
expect_contains /tmp/campfire_bench_validate.out '"extra_long_horizon"'

echo "== Result scoring =="
python3 "$RUNNER" --root "$ROOT_DIR" --results-dir "$BENCH_ROOT/fixtures/results" >/tmp/campfire_bench_score.out
expect_contains /tmp/campfire_bench_score.out '"result_count": 1'
expect_contains /tmp/campfire_bench_score.out '"scenario_id": "resume-after-interrupt"'
expect_contains /tmp/campfire_bench_score.out '"orchestration_token_ratio": 0.15'

echo "PASS: Campfire benchmark verification completed."
