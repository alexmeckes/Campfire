#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_ROOT="${CAMPFIRE_SKILLS_ROOT:-$ROOT_DIR/skills}"
WORKSPACE_ROOT="$ROOT_DIR/benchmarks/campfire-bench/workspaces"

expect_file() {
  local path="$1"
  [ -e "$path" ] || { echo "Missing required path: $path" >&2; exit 1; }
}

echo "== Syntax checks =="
zsh -n "$ROOT_DIR/scripts/verify_benchmark_workspaces.sh"
zsh -n "$WORKSPACE_ROOT/fixture-long-run/scripts/verify_fixture_workspace.sh" "$WORKSPACE_ROOT/fixture-long-run/scripts/verify_harness.sh"
zsh -n "$WORKSPACE_ROOT/fixture-extra-long-run/scripts/verify_fixture_workspace.sh" "$WORKSPACE_ROOT/fixture-extra-long-run/scripts/verify_harness.sh"

echo "== Fixture workspace presence =="
expect_file "$WORKSPACE_ROOT/fixture-long-run/AGENTS.md"
expect_file "$WORKSPACE_ROOT/fixture-long-run/campfire.toml"
expect_file "$WORKSPACE_ROOT/fixture-long-run/.autonomous/fixture-long-run/checkpoints.json"
expect_file "$WORKSPACE_ROOT/fixture-extra-long-run/AGENTS.md"
expect_file "$WORKSPACE_ROOT/fixture-extra-long-run/campfire.toml"
expect_file "$WORKSPACE_ROOT/fixture-extra-long-run/.autonomous/fixture-extra-long-run/checkpoints.json"

echo "== Fixture long-run workspace =="
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$WORKSPACE_ROOT/fixture-long-run/scripts/verify_harness.sh"

echo "== Fixture extra-long-run workspace =="
CAMPFIRE_SKILLS_ROOT="$SKILLS_ROOT" "$WORKSPACE_ROOT/fixture-extra-long-run/scripts/verify_harness.sh"

echo "PASS: Benchmark fixture workspace verification completed."
