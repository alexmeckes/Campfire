#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
REFRESH_REGISTRY_SCRIPT="$SKILL_DIR/scripts/refresh_registry.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_contains() {
  local path="$1"
  local pattern="$2"
  if ! /usr/bin/grep -q "$pattern" "$path"; then
    fail "Expected pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$INIT_SCRIPT" "$START_SLICE_SCRIPT" "$REFRESH_REGISTRY_SCRIPT"

echo "== Registry refresh =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_registry.out' EXIT

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "task-one" "registry task one" >/dev/null
"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "task-two" "registry task two" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --milestone-id "milestone-001" \
  --milestone-title "Registry pulse" \
  --slice-title "Drive the first heartbeat" \
  "task-two" >/dev/null
"$REFRESH_REGISTRY_SCRIPT" --root "$TEMP_WORKSPACE" >/tmp/campfire_registry.out

REGISTRY_FILE="$TEMP_WORKSPACE/.campfire/registry.json"
expect_contains "$REGISTRY_FILE" '"task_count": 2'
expect_contains "$REGISTRY_FILE" '"task_slug": "task-one"'
expect_contains "$REGISTRY_FILE" '"task_slug": "task-two"'
expect_contains "$REGISTRY_FILE" '"state": "active"'
expect_contains "$REGISTRY_FILE" '"state": "idle"'
expect_contains /tmp/campfire_registry.out 'Registry rendered:'

echo "PASS: Registry refresh verification completed."
