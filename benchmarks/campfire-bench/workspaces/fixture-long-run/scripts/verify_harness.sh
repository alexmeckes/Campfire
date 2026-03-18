#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

expect_file() {
  local path="$1"
  [ -e "$path" ] || { echo "Missing required path: $path" >&2; exit 1; }
}

zsh -n "$ROOT_DIR/scripts/verify_harness.sh" "$ROOT_DIR/scripts/verify_fixture_workspace.sh"

expect_file "$ROOT_DIR/.claude/settings.json"
expect_file "$ROOT_DIR/.claude/commands/campfire-resume.md"
expect_file "$ROOT_DIR/.claude/hooks/campfire-session-start.sh"
expect_file "$ROOT_DIR/.autonomous/fixture-long-run/checkpoints.json"

zsh "$ROOT_DIR/scripts/verify_fixture_workspace.sh"

echo "PASS: Fixture long-run harness verification completed."
