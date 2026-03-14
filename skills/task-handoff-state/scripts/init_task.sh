#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
TASK_SLUG=""

usage() {
  cat <<'EOF'
Usage:
  init_task.sh [--root /path/to/workspace] [--slug task-slug] "task objective"
EOF
}

slugify() {
  local value
  value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')"
  printf '%s' "${value:-task}"
}

POSITIONAL=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --slug)
      TASK_SLUG="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [ "${#POSITIONAL[@]}" -lt 1 ]; then
  usage >&2
  exit 1
fi

OBJECTIVE="${POSITIONAL[1]}"
TASK_SLUG="${TASK_SLUG:-$(slugify "$OBJECTIVE")}"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
TASK_DIR="$ROOT_DIR/.autonomous/$TASK_SLUG"
TODAY="$(date +%Y-%m-%d)"
NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p "$TASK_DIR/logs" "$TASK_DIR/artifacts" "$TASK_DIR/findings"

PLAN_FILE="$TASK_DIR/plan.md"
RUNBOOK_FILE="$TASK_DIR/runbook.md"
PROGRESS_FILE="$TASK_DIR/progress.md"
HANDOFF_FILE="$TASK_DIR/handoff.md"
CHECKPOINT_FILE="$TASK_DIR/checkpoints.json"
ARTIFACTS_FILE="$TASK_DIR/artifacts.json"

if [ ! -f "$PLAN_FILE" ]; then
  cat > "$PLAN_FILE" <<EOF
# $TASK_SLUG

## Objective

$OBJECTIVE

## Source Docs

- Add project-specific source-of-truth docs here

## Milestones

- [ ] Clarify the current milestone and required files
- [ ] Implement the next dependency-safe slice
- [ ] Validate the slice with the strongest available evidence
- [ ] Update progress and handoff state

## Notes

- Created: $TODAY
- If this workspace has an AGENTS.md file, follow it
EOF
fi

if [ ! -f "$RUNBOOK_FILE" ]; then
  cat > "$RUNBOOK_FILE" <<EOF
# Runbook

## Workspace

- Root: $ROOT_DIR
- Task: $TASK_SLUG

## Boot / Setup

- Add project-specific setup commands here
- Add required tools, services, or ports here

## Validation

- Add the primary validation commands here
- Add secondary checks or manual verification here
- Record where validation artifacts should be stored

## Observability

- Logs: .autonomous/$TASK_SLUG/logs/
- Artifacts: .autonomous/$TASK_SLUG/artifacts/
- Findings: .autonomous/$TASK_SLUG/findings/

## Notes

- Keep this file current as setup, tooling, or validation changes
EOF
fi

if [ ! -f "$PROGRESS_FILE" ]; then
  cat > "$PROGRESS_FILE" <<EOF
# Progress Log

## $TODAY

- Task created.
- Objective: $OBJECTIVE
- Next slice: define the first milestone and validation target.
EOF
fi

if [ ! -f "$HANDOFF_FILE" ]; then
  cat > "$HANDOFF_FILE" <<EOF
# Handoff

## Current Status

- Status: ready
- Current milestone: not started
- Next slice: define the first dependency-safe implementation step
- Stop reason: initialized

## Resume Prompt

Use \$long-horizon-worker and \$task-handoff-state to continue this task from \`.autonomous/$TASK_SLUG/\` and keep working until the current milestone is validated or a real blocker appears.
EOF
fi

if [ -f "$HANDOFF_FILE" ] && ! grep -q "^- Stop reason:" "$HANDOFF_FILE"; then
  awk '
    /^- Next slice:/ {
      print
      print "- Stop reason: initialized"
      next
    }
    { print }
  ' "$HANDOFF_FILE" > "$HANDOFF_FILE.tmp"
  mv "$HANDOFF_FILE.tmp" "$HANDOFF_FILE"
fi

if [ ! -f "$ARTIFACTS_FILE" ]; then
  cat > "$ARTIFACTS_FILE" <<EOF
{
  "task_slug": "$TASK_SLUG",
  "last_updated": "$TODAY",
  "artifacts": [],
  "notes": "Record files, logs, screenshots, reports, or outputs that matter for review or resumption."
}
EOF
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to normalize checkpoints.json" >&2
  exit 1
fi

export CHECKPOINT_FILE TASK_SLUG TODAY NOW_UTC OBJECTIVE

python3 <<'PY'
import json
import os
from pathlib import Path

path = Path(os.environ["CHECKPOINT_FILE"])
task_slug = os.environ["TASK_SLUG"]
objective = os.environ["OBJECTIVE"]
today = os.environ["TODAY"]
now_utc = os.environ["NOW_UTC"]

data = {}
if path.exists():
    try:
        data = json.loads(path.read_text())
        if not isinstance(data, dict):
            data = {}
    except Exception:
        data = {}

status = data.get("status", "ready")
phase = data.get("phase", "planning" if status == "ready" else "execution")

current = data.get("current", {})
if not isinstance(current, dict):
    current = {}

current_milestone = data.get("current_milestone", "")
current_slice = data.get("current_slice", "")

blocker = data.get("blocker", {})
if not isinstance(blocker, dict):
    blocker = {}

last_run = data.get("last_run", {})
if not isinstance(last_run, dict):
    last_run = {}
last_run_events = last_run.get("events", [])
if not isinstance(last_run_events, list):
    last_run_events = []

validation = data.get("validation", [])
if not isinstance(validation, list):
    validation = []

workspace = data.get("workspace", {})
if not isinstance(workspace, dict):
    workspace = {}

normalized = {
    "task_slug": task_slug,
    "objective": data.get("objective", objective),
    "status": status,
    "phase": phase,
    "current": {
        "milestone_id": current.get("milestone_id", ""),
        "milestone_title": current.get("milestone_title", current_milestone),
        "slice_id": current.get("slice_id", ""),
        "slice_title": current.get("slice_title", current_slice),
        "acceptance_criteria": current.get("acceptance_criteria", []),
        "dependencies": current.get("dependencies", []),
    },
    "execution": {
        "mode": data.get("execution", {}).get("mode", "single_milestone") if isinstance(data.get("execution", {}), dict) else "single_milestone",
        "auto_advance": data.get("execution", {}).get("auto_advance", False) if isinstance(data.get("execution", {}), dict) else False,
        "auto_reframe": data.get("execution", {}).get("auto_reframe", False) if isinstance(data.get("execution", {}), dict) else False,
        "planning_slice_minutes": data.get("execution", {}).get("planning_slice_minutes", 15) if isinstance(data.get("execution", {}), dict) else 15,
        "runtime_budget_minutes": data.get("execution", {}).get("runtime_budget_minutes", 0) if isinstance(data.get("execution", {}), dict) else 0,
        "max_milestones_per_run": data.get("execution", {}).get("max_milestones_per_run", 1) if isinstance(data.get("execution", {}), dict) else 1,
        "reframe_queue_below": data.get("execution", {}).get("reframe_queue_below", 0) if isinstance(data.get("execution", {}), dict) else 0,
        "target_queue_depth": data.get("execution", {}).get("target_queue_depth", 0) if isinstance(data.get("execution", {}), dict) else 0,
        "max_reframes_per_run": data.get("execution", {}).get("max_reframes_per_run", 0) if isinstance(data.get("execution", {}), dict) else 0,
        "continue_until": data.get("execution", {}).get(
            "continue_until",
            ["milestone_validated", "blocked", "waiting_on_decision"],
        ) if isinstance(data.get("execution", {}), dict) else ["milestone_validated", "blocked", "waiting_on_decision"],
        "queued_milestones": data.get("execution", {}).get("queued_milestones", []) if isinstance(data.get("execution", {}), dict) else [],
        "notes": data.get("execution", {}).get("notes", "") if isinstance(data.get("execution", {}), dict) else "",
    },
    "blocker": {
        "status": blocker.get("status", "none"),
        "type": blocker.get("type", ""),
        "summary": blocker.get("summary", ""),
        "attempts": blocker.get("attempts", 0),
        "next_action": blocker.get("next_action", ""),
    },
    "workspace": {
        "strategy": workspace.get("strategy", ""),
        "root": workspace.get("root", ""),
        "git_root": workspace.get("git_root", ""),
        "branch": workspace.get("branch", ""),
    },
    "last_run": {
        "started_at": last_run.get("started_at", ""),
        "ended_at": last_run.get("ended_at") or (now_utc if status == "ready" else ""),
        "stop_reason": last_run.get("stop_reason") or ("initialized" if status == "ready" else ""),
        "summary": last_run.get("summary") or ("Task scaffold created or normalized." if status == "ready" else ""),
        "next_step": last_run.get("next_step") or ("Define the first milestone and validation target." if status == "ready" else ""),
        "events": last_run_events,
    },
    "runbook": "runbook.md",
    "artifacts_manifest": "artifacts.json",
    "validation": validation,
    "last_updated": today,
}

path.write_text(json.dumps(normalized, indent=2) + "\n")
PY

echo "Created or reused task directory:"
echo "  $TASK_DIR"
echo
echo "Recommended Codex App prompt:"
echo "  Use \$long-horizon-worker and \$task-handoff-state to continue .autonomous/$TASK_SLUG/ and keep working until the current milestone is validated."
