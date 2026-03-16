#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPT_TEMPLATE_SCRIPT="${PROMPT_TEMPLATE_SCRIPT:-$SCRIPT_DIR/prompt_template_helper.sh}"
TOUCH_HEARTBEAT_SCRIPT="${TOUCH_HEARTBEAT_SCRIPT:-$SCRIPT_DIR/touch_heartbeat.sh}"
REFRESH_REGISTRY_SCRIPT="${REFRESH_REGISTRY_SCRIPT:-$SCRIPT_DIR/refresh_registry.sh}"
FROM_NEXT=false
MILESTONE_ID=""
MILESTONE_TITLE=""
SLICE_ID=""
SLICE_TITLE=""
NEXT_SLICE=""
SUMMARY_TEXT=""
RUN_ID=""
PARENT_RUN_ID=""
LINEAGE_KIND=""
BRANCH_LABEL=""

usage() {
  cat <<'EOF'
Usage:
  start_slice.sh [--root /path/to/workspace] [--from-next] [--milestone-id id] [--milestone-title title] [--slice-id id] [--slice-title title] [--next-slice text] [--summary text] [--run-id value] [--parent-run-id value] [--lineage-kind retry|course_correction|benchmark_repro] [--branch-label text] <task-slug>

Examples:
  start_slice.sh --root /path/to/workspace --from-next --slice-title "Implement the next safe slice" my-task
  start_slice.sh --milestone-id milestone-003 --milestone-title "Camp Loop" --slice-title "Wire save/load buttons" my-task
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --from-next)
      FROM_NEXT=true
      shift
      ;;
    --milestone-id)
      MILESTONE_ID="$2"
      shift 2
      ;;
    --milestone-title)
      MILESTONE_TITLE="$2"
      shift 2
      ;;
    --slice-id)
      SLICE_ID="$2"
      shift 2
      ;;
    --slice-title)
      SLICE_TITLE="$2"
      shift 2
      ;;
    --next-slice)
      NEXT_SLICE="$2"
      shift 2
      ;;
    --summary)
      SUMMARY_TEXT="$2"
      shift 2
      ;;
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --parent-run-id)
      PARENT_RUN_ID="$2"
      shift 2
      ;;
    --lineage-kind)
      LINEAGE_KIND="$2"
      shift 2
      ;;
    --branch-label)
      BRANCH_LABEL="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 1
fi

TASK_SLUG="$1"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
TASK_DIR="$ROOT_DIR/.autonomous/$TASK_SLUG"
CHECKPOINT_FILE="$TASK_DIR/checkpoints.json"
HANDOFF_FILE="$TASK_DIR/handoff.md"
PROGRESS_FILE="$TASK_DIR/progress.md"
ARTIFACTS_FILE="$TASK_DIR/artifacts.json"

if [ ! -d "$TASK_DIR" ]; then
  echo "Task not found: $TASK_DIR" >&2
  exit 1
fi

for required in "$CHECKPOINT_FILE" "$HANDOFF_FILE" "$PROGRESS_FILE"; do
  if [ ! -f "$required" ]; then
    echo "Missing required task file: $required" >&2
    exit 1
  fi
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to start a slice" >&2
  exit 1
fi

export CHECKPOINT_FILE HANDOFF_FILE PROGRESS_FILE ARTIFACTS_FILE TASK_SLUG FROM_NEXT MILESTONE_ID MILESTONE_TITLE SLICE_ID SLICE_TITLE NEXT_SLICE SUMMARY_TEXT RUN_ID PARENT_RUN_ID LINEAGE_KIND BRANCH_LABEL ROOT_DIR PROMPT_TEMPLATE_SCRIPT

python3 <<'PY'
import json
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def slugify(value: str) -> str:
    lowered = value.strip().lower()
    lowered = re.sub(r"[^a-z0-9]+", "-", lowered)
    lowered = re.sub(r"-{2,}", "-", lowered).strip("-")
    return lowered or "slice"


def load_json(path: Path) -> dict:
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise SystemExit(f"Expected a JSON object in {path}")
    return data


def normalize_queue(raw_queue):
    normalized = []
    if not isinstance(raw_queue, list):
        return normalized
    for item in raw_queue:
        if isinstance(item, dict):
            milestone_id = str(item.get("milestone_id", "")).strip()
            milestone_title = str(item.get("milestone_title", "")).strip()
        elif isinstance(item, str):
            text = item.strip()
            if ":" in text:
                milestone_id, milestone_title = text.split(":", 1)
                milestone_id = milestone_id.strip()
                milestone_title = milestone_title.strip()
            else:
                milestone_id = text
                milestone_title = text
        else:
            continue
        if milestone_id:
            normalized.append(
                {"milestone_id": milestone_id, "milestone_title": milestone_title}
            )
    return normalized


def extract_resume_prompt(handoff_text: str) -> str:
    if "## Resume Prompt" not in handoff_text:
        return ""
    after = handoff_text.split("## Resume Prompt", 1)[1].lstrip()
    return after.strip()


def normalize_lineage_kind(value: str) -> str:
    text = value.strip().lower()
    aliases = {
        "retry": "retry",
        "course_correction": "course_correction",
        "course-correction": "course_correction",
        "benchmark_repro": "benchmark_repro",
        "benchmark-repro": "benchmark_repro",
        "repro": "benchmark_repro",
    }
    if not text:
        return ""
    if text not in aliases:
        raise SystemExit(f"Unsupported lineage kind: {value}")
    return aliases[text]


checkpoint_path = Path(os.environ["CHECKPOINT_FILE"])
handoff_path = Path(os.environ["HANDOFF_FILE"])
progress_path = Path(os.environ["PROGRESS_FILE"])
artifacts_path = Path(os.environ["ARTIFACTS_FILE"])
task_slug = os.environ["TASK_SLUG"]
from_next = os.environ["FROM_NEXT"].strip().lower() == "true"
requested_milestone_id = os.environ["MILESTONE_ID"].strip()
requested_milestone_title = os.environ["MILESTONE_TITLE"].strip()
requested_slice_id = os.environ["SLICE_ID"].strip()
requested_slice_title = os.environ["SLICE_TITLE"].strip()
requested_next_slice = os.environ["NEXT_SLICE"].strip()
summary_text = os.environ["SUMMARY_TEXT"].strip()
requested_run_id = os.environ["RUN_ID"].strip()
parent_run_id = os.environ["PARENT_RUN_ID"].strip()
lineage_kind = normalize_lineage_kind(os.environ["LINEAGE_KIND"])
branch_label = os.environ["BRANCH_LABEL"].strip()

if (parent_run_id or branch_label) and not lineage_kind:
    raise SystemExit("--lineage-kind is required when parent or branch metadata is provided")

checkpoint = load_json(checkpoint_path)
execution = checkpoint.get("execution", {})
if not isinstance(execution, dict):
    execution = {}

resume_prompt = extract_resume_prompt(handoff_path.read_text())
if not resume_prompt:
    resume_prompt = subprocess.run(
        [
            os.environ["PROMPT_TEMPLATE_SCRIPT"],
            "--root",
            os.environ["ROOT_DIR"],
            "--task-slug",
            task_slug,
            "resume",
        ],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()

current = checkpoint.get("current", {})
if not isinstance(current, dict):
    current = {}

queued = normalize_queue(execution.get("queued_milestones", []))

selected_id = requested_milestone_id
selected_title = requested_milestone_title

if from_next:
    if queued:
      next_entry = queued.pop(0)
      selected_id = selected_id or next_entry["milestone_id"]
      selected_title = selected_title or next_entry["milestone_title"]
    elif current.get("milestone_id"):
      selected_id = selected_id or str(current.get("milestone_id", "")).strip()
      selected_title = selected_title or str(current.get("milestone_title", "")).strip()
    else:
      raise SystemExit("--from-next requested but no queued or current milestone exists")

if not selected_id:
    selected_id = str(current.get("milestone_id", "")).strip()
if not selected_title:
    if selected_id and selected_id == str(current.get("milestone_id", "")).strip():
        selected_title = str(current.get("milestone_title", "")).strip()
    else:
        for entry in queued:
            if entry["milestone_id"] == selected_id:
                selected_title = entry["milestone_title"]
                break

if not selected_id:
    raise SystemExit("No milestone selected. Pass --from-next or --milestone-id.")

if not selected_title:
    selected_title = selected_id

same_milestone = selected_id == str(current.get("milestone_id", "")).strip()
acceptance = current.get("acceptance_criteria", []) if same_milestone else []
dependencies = current.get("dependencies", []) if same_milestone else []
if not isinstance(acceptance, list):
    acceptance = []
if not isinstance(dependencies, list):
    dependencies = []

slice_title = requested_slice_title or str(current.get("slice_title", "")).strip()
if not slice_title:
    slice_title = selected_title
slice_id = requested_slice_id or slugify(slice_title)
next_slice = requested_next_slice or f"Implement and validate {slice_title.lower()}."

checkpoint["status"] = "in_progress"
checkpoint["phase"] = "implementation"
checkpoint["current"] = {
    "milestone_id": selected_id,
    "milestone_title": selected_title,
    "slice_id": slice_id,
    "slice_title": slice_title,
    "acceptance_criteria": acceptance,
    "dependencies": dependencies,
}

execution["queued_milestones"] = queued
checkpoint["execution"] = execution

now = datetime.now(timezone.utc)
today = now.strftime("%Y-%m-%d")
now_utc = now.isoformat(timespec="microseconds").replace("+00:00", "Z")
run_id = requested_run_id or f"run-{now.strftime('%Y%m%dT%H%M%S%fZ')}"
last_run = checkpoint.get("last_run", {})
if not isinstance(last_run, dict):
    last_run = {}
events = last_run.get("events", [])
if not isinstance(events, list):
    events = []
if "slice_started" not in events:
    events.append("slice_started")
last_run.update(
    {
        "started_at": now_utc,
        "ended_at": "",
        "stop_reason": "",
        "run_id": run_id,
        "summary": summary_text or f"Started {selected_id} / {slice_id}: {slice_title}.",
        "next_step": next_slice,
        "events": events,
    }
)
if lineage_kind or parent_run_id or branch_label:
    last_run["lineage"] = {
        "parent_run_id": parent_run_id,
        "kind": lineage_kind,
        "branch_label": branch_label,
    }
else:
    last_run.pop("lineage", None)
checkpoint["last_run"] = last_run
checkpoint["last_updated"] = today
checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n")

handoff_text = "\n".join(
    [
        "# Handoff",
        "",
        "## Current Status",
        "",
        "- Status: in progress",
        f"- Current milestone: `{selected_id}` - {selected_title}",
        f"- Next slice: {next_slice}",
        "- Stop reason: active milestone work",
        "",
        "## Resume Prompt",
        "",
        resume_prompt,
        "",
    ]
)
handoff_path.write_text(handoff_text)

progress_text = progress_path.read_text().rstrip()
today_header = f"## {today}"
progress_lines = progress_text.splitlines()
entry_lines = [
    f"- Started `{selected_id}` / `{slice_id}`.",
    f"- Active slice: {slice_title}",
    f"- Validation target: {next_slice}",
]

if today_header in progress_lines:
    index = progress_lines.index(today_header) + 1
    progress_lines[index:index] = [""]
    insert_at = index + 1
    progress_lines[insert_at:insert_at] = entry_lines
    updated_progress = "\n".join(progress_lines).rstrip() + "\n"
else:
    updated_progress = (
        progress_text
        + ("\n\n" if progress_text else "")
        + today_header
        + "\n\n"
        + "\n".join(entry_lines)
        + "\n"
    )
progress_path.write_text(updated_progress)

if artifacts_path.exists():
    artifacts = load_json(artifacts_path)
    artifacts["last_updated"] = today
    artifacts_path.write_text(json.dumps(artifacts, indent=2) + "\n")

print(f"Activated task: {task_slug}")
print(f"  milestone: {selected_id} - {selected_title}")
print(f"  slice: {slice_id} - {slice_title}")
print(f"  next_slice: {next_slice}")
if queued:
    print("  remaining_queue:")
    for entry in queued:
        print(f"    - {entry['milestone_id']}: {entry['milestone_title']}")
PY

SESSION_STARTED_AT="$(python3 - <<'PY'
from datetime import datetime, timezone
print(datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z"))
PY
)"

if [ -x "$TOUCH_HEARTBEAT_SCRIPT" ]; then
  "$TOUCH_HEARTBEAT_SCRIPT" --root "$ROOT_DIR" --state active --session-started-at "$SESSION_STARTED_AT" --source "start_slice.sh" --summary "${SUMMARY_TEXT:-Started slice.}" "$TASK_SLUG" >/dev/null
fi

if [ -x "$REFRESH_REGISTRY_SCRIPT" ]; then
  "$REFRESH_REGISTRY_SCRIPT" --root "$ROOT_DIR" >/dev/null
fi
