#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
ENABLE_SCRIPT="$SKILL_DIR/scripts/enable_rolling_mode.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
HELPER_SCRIPT="$SKILL_DIR/scripts/automation_schedule_scaffold.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_automation_schedule_scaffold.sh"

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

expect_not_contains() {
  local path="$1"
  local pattern="$2"
  if /usr/bin/grep -Fq -- "$pattern" "$path"; then
    fail "Did not expect pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$INIT_SCRIPT" "$ENABLE_SCRIPT" "$START_SLICE_SCRIPT" "$HELPER_SCRIPT" "$SELF_SCRIPT"

echo "== Automation schedule scaffold flow =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_schedule_scaffolds.json /tmp/campfire_schedule_scaffolds.out' EXIT
TASK_SLUG="verify-automation-schedule-scaffold"

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify automation schedule scaffold helper" >/dev/null

"$ENABLE_SCRIPT" \
  --root "$TEMP_WORKSPACE" \
  --until-stopped \
  --queue "milestone-002:Extend the automation cadence backlog" \
  --queue "milestone-003:Evaluate the schedule scaffold output" \
  "$TASK_SLUG" >/dev/null

"$START_SLICE_SCRIPT" \
  --root "$TEMP_WORKSPACE" \
  --milestone-id "milestone-001" \
  --milestone-title "Verify automation schedule scaffold helper" \
  --slice-id "slice-001-automation-schedule-scaffolds" \
  --slice-title "Draft automation schedule scaffold metadata" \
  "$TASK_SLUG" >/dev/null

"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" --json "$TASK_SLUG" >/tmp/campfire_schedule_scaffolds.json
python3 - "$TEMP_WORKSPACE" <<'PY'
import json
import sys
from pathlib import Path

workspace = Path(sys.argv[1]).resolve()
payload = json.loads(Path("/tmp/campfire_schedule_scaffolds.json").read_text())
scaffolds = payload.get("scaffolds", [])
if len(scaffolds) != 3:
    raise SystemExit("expected three automation schedule scaffolds")
expected_variants = ["rolling_resume", "verifier_sweep", "backlog_refresh"]
variants = [item.get("variant") for item in scaffolds]
if variants != expected_variants:
    raise SystemExit(f"unexpected scaffold variants: {variants}")
expected_labels = {
    "rolling_resume": "Nightly rolling resume",
    "verifier_sweep": "Nightly verifier sweep",
    "backlog_refresh": "Weekly backlog refresh",
}
for scaffold in scaffolds:
    variant = scaffold["variant"]
    if scaffold.get("cadence_label") != expected_labels[variant]:
        raise SystemExit(f"unexpected cadence label for {variant}")
    if scaffold.get("platform_scope") != "generic":
        raise SystemExit(f"unexpected platform scope for {variant}")
    if scaffold.get("scheduler_binding") != "operator_owned":
        raise SystemExit(f"unexpected scheduler binding for {variant}")
    if scaffold.get("local_first") is not True:
        raise SystemExit(f"unexpected local_first for {variant}")
    if len(scaffold.get("schedule_examples", [])) < 2:
        raise SystemExit(f"missing schedule examples for {variant}")
    if len(scaffold.get("operator_questions", [])) < 2:
        raise SystemExit(f"missing operator questions for {variant}")
    if not str(scaffold.get("proposal_name", "")).strip():
        raise SystemExit(f"missing proposal name for {variant}")
    if scaffold.get("run_style") != "until_stopped":
        raise SystemExit(f"unexpected run style for {variant}")
print("Automation schedule scaffold metadata verified.")
PY

"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" --variant verifier_sweep "$TASK_SLUG" >/tmp/campfire_schedule_scaffolds.out
expect_contains /tmp/campfire_schedule_scaffolds.out 'verifier_sweep:'
expect_contains /tmp/campfire_schedule_scaffolds.out 'cadence_label: Nightly verifier sweep'
expect_contains /tmp/campfire_schedule_scaffolds.out 'platform_scope: generic'
expect_not_contains /tmp/campfire_schedule_scaffolds.out 'rolling_resume:'
expect_not_contains /tmp/campfire_schedule_scaffolds.out 'backlog_refresh:'
expect_not_contains /tmp/campfire_schedule_scaffolds.out 'RRULE'
expect_not_contains /tmp/campfire_schedule_scaffolds.out 'FREQ='
expect_not_contains /tmp/campfire_schedule_scaffolds.out '::automation-update'

echo "PASS: Automation schedule scaffold verification completed."
