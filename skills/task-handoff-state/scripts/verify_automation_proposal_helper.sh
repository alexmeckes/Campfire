#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
ENABLE_ROLLING_SCRIPT="$SKILL_DIR/scripts/enable_rolling_mode.sh"
START_SLICE_SCRIPT="$SKILL_DIR/scripts/start_slice.sh"
HELPER_SCRIPT="$SKILL_DIR/scripts/automation_proposal_helper.sh"
PROMPT_TEMPLATE_SCRIPT="$SKILL_DIR/scripts/prompt_template_helper.sh"

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
zsh -n "$INIT_SCRIPT" "$ENABLE_ROLLING_SCRIPT" "$START_SLICE_SCRIPT" "$PROMPT_TEMPLATE_SCRIPT" "$HELPER_SCRIPT" "$0"

echo "== Automation proposal flow =="
TEMP_WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$TEMP_WORKSPACE" /tmp/campfire_automation_proposals.json /tmp/campfire_automation_proposal_verifier.out' EXIT
TASK_SLUG="verify-automation-proposal-helper"

cat >"$TEMP_WORKSPACE/campfire.toml" <<'EOF'
version = 1
project_name = "Automation Proposal Verifier"
default_task_root = ".tasks"
EOF

"$INIT_SCRIPT" --root "$TEMP_WORKSPACE" --slug "$TASK_SLUG" "verify automation proposal helper" >/dev/null
"$ENABLE_ROLLING_SCRIPT" --root "$TEMP_WORKSPACE" --until-stopped --queue "milestone-002:Next slice" --queue "milestone-003:Follow-up slice" "$TASK_SLUG" >/dev/null
"$START_SLICE_SCRIPT" --root "$TEMP_WORKSPACE" --milestone-id "milestone-001" --milestone-title "Verify automation proposal helper" --slice-id "slice-001-automation-proposals" --slice-title "Draft automation proposal metadata" "$TASK_SLUG" >/dev/null

"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" --json "$TASK_SLUG" >/tmp/campfire_automation_proposals.json

python3 - "$TEMP_WORKSPACE" <<'PY'
import json
import sys
from pathlib import Path

workspace = Path(sys.argv[1]).resolve()
payload = json.loads(Path("/tmp/campfire_automation_proposals.json").read_text())
proposals = payload.get("proposals", [])
if len(proposals) != 3:
    raise SystemExit("expected three automation proposals")

expected_variants = ["rolling_resume", "verifier_sweep", "backlog_refresh"]
variants = [item.get("variant") for item in proposals]
if variants != expected_variants:
    raise SystemExit(f"variant mismatch: {variants}")

expected_names = {
    "rolling_resume": "Continue verify-automation-proposal-helper",
    "verifier_sweep": "Sweep verify-automation-proposal-helper verifier",
    "backlog_refresh": "Refresh verify-automation-proposal-helper backlog",
}

for proposal in proposals:
    variant = proposal["variant"]
    if proposal.get("name") != expected_names[variant]:
        raise SystemExit(f"name mismatch for {variant}")
    if proposal.get("cwds") != [str(workspace)]:
        raise SystemExit(f"cwd mismatch for {variant}")
    if proposal.get("status") != "ACTIVE":
        raise SystemExit(f"status mismatch for {variant}")
    if proposal.get("mode") != "rolling":
        raise SystemExit(f"mode mismatch for {variant}")
    if proposal.get("run_style") != "until_stopped":
        raise SystemExit(f"run style mismatch for {variant}")
    if not str(proposal.get("prompt", "")).startswith("Use $"):
        raise SystemExit(f"prompt mismatch for {variant}")
    if not proposal.get("current_milestone_id"):
        raise SystemExit(f"missing milestone metadata for {variant}")
    if not proposal.get("current_slice_id"):
        raise SystemExit(f"missing slice metadata for {variant}")

print("Automation proposal metadata verified.")
PY

"$HELPER_SCRIPT" --root "$TEMP_WORKSPACE" --variant verifier_sweep "$TASK_SLUG" >/tmp/campfire_automation_proposal_verifier.out
expect_contains /tmp/campfire_automation_proposal_verifier.out 'verifier_sweep:'
expect_contains /tmp/campfire_automation_proposal_verifier.out 'name: Sweep verify-automation-proposal-helper verifier'
expect_not_contains /tmp/campfire_automation_proposal_verifier.out 'rolling_resume:'
expect_not_contains /tmp/campfire_automation_proposal_verifier.out 'backlog_refresh:'

echo "PASS: Automation proposal helper verification completed."
