#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REFRESH_REGISTRY_SCRIPT="${REFRESH_REGISTRY_SCRIPT:-$SCRIPT_DIR/refresh_registry.sh}"
MODE=""
SUMMARY=""
DETAILS=""
SOURCE="operator"
CLEAR_ACTIVE=false
CLEAR_FOLLOW_UPS=false

usage() {
  cat <<'EOF'
Usage:
  queue_guidance.sh [--root /path/to/workspace] [--mode interrupt_now|next_boundary] [--summary text] [--details text] [--source text] [--clear-active] [--clear-follow-ups] <task-slug>

Examples:
  queue_guidance.sh --mode interrupt_now --summary "Stop and inspect the failing verifier." improve-campfire
  queue_guidance.sh --mode next_boundary --summary "Revisit session lineage after milestone 042." improve-campfire
  queue_guidance.sh --clear-active improve-campfire
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --summary)
      SUMMARY="$2"
      shift 2
      ;;
    --details)
      DETAILS="$2"
      shift 2
      ;;
    --source)
      SOURCE="$2"
      shift 2
      ;;
    --clear-active)
      CLEAR_ACTIVE=true
      shift
      ;;
    --clear-follow-ups)
      CLEAR_FOLLOW_UPS=true
      shift
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

if [ -z "$SUMMARY" ] && [ "$CLEAR_ACTIVE" = false ] && [ "$CLEAR_FOLLOW_UPS" = false ]; then
  echo "Provide --summary to queue guidance or use a clear flag." >&2
  exit 1
fi

TASK_SLUG="$1"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
TASK_DIR="$ROOT_DIR/.autonomous/$TASK_SLUG"
CHECKPOINT_FILE="$TASK_DIR/checkpoints.json"

if [ ! -f "$CHECKPOINT_FILE" ]; then
  echo "Task checkpoints missing: $CHECKPOINT_FILE" >&2
  exit 1
fi

export CHECKPOINT_FILE MODE SUMMARY DETAILS SOURCE CLEAR_ACTIVE CLEAR_FOLLOW_UPS ROOT_DIR REFRESH_REGISTRY_SCRIPT

python3 <<'PY'
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def load_json(path: Path) -> dict:
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise SystemExit(f"Expected JSON object in {path}")
    return data


def normalize_mode(value: str) -> str:
    text = value.strip().lower()
    aliases = {
        "interrupt_now": "interrupt_now",
        "interrupt-now": "interrupt_now",
        "interrupt": "interrupt_now",
        "urgent": "interrupt_now",
        "next_boundary": "next_boundary",
        "next-boundary": "next_boundary",
        "boundary": "next_boundary",
        "follow_up": "next_boundary",
        "follow-up": "next_boundary",
    }
    if not text:
        return ""
    if text not in aliases:
        raise SystemExit(f"Unsupported guidance mode: {value}")
    return aliases[text]


def format_command_error(exc: Exception) -> str:
    if isinstance(exc, subprocess.CalledProcessError):
        detail = (exc.stderr or exc.stdout or "").strip()
        if detail:
            return detail
    return str(exc)


def refresh_registry() -> None:
    subprocess.run(
        [os.environ["REFRESH_REGISTRY_SCRIPT"], "--root", os.environ["ROOT_DIR"]],
        check=True,
        capture_output=True,
        text=True,
    )


checkpoint_path = Path(os.environ["CHECKPOINT_FILE"])
mode = normalize_mode(os.environ["MODE"])
summary = os.environ["SUMMARY"].strip()
details = os.environ["DETAILS"].strip()
source = os.environ["SOURCE"].strip() or "operator"
clear_active = os.environ["CLEAR_ACTIVE"].strip().lower() == "true"
clear_follow_ups = os.environ["CLEAR_FOLLOW_UPS"].strip().lower() == "true"

checkpoint = load_json(checkpoint_path)
original_checkpoint_text = checkpoint_path.read_text()
guidance = checkpoint.get("guidance", {})
if not isinstance(guidance, dict):
    guidance = {}

if clear_active:
    guidance.pop("active", None)
if clear_follow_ups:
    guidance["follow_ups"] = []

if summary:
    if not mode:
        raise SystemExit("--mode is required when --summary is provided")
    entry = {
        "mode": mode,
        "summary": summary,
        "details": details,
        "source": source,
        "created_at": datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z"),
    }
    if mode == "interrupt_now":
        guidance["active"] = entry
    else:
        follow_ups = guidance.get("follow_ups", [])
        if not isinstance(follow_ups, list):
            follow_ups = []
        follow_ups.append(entry)
        guidance["follow_ups"] = follow_ups

if not guidance.get("active") and not guidance.get("follow_ups"):
    checkpoint.pop("guidance", None)
else:
    checkpoint["guidance"] = guidance

checkpoint["last_updated"] = datetime.now(timezone.utc).strftime("%Y-%m-%d")
checkpoint_path.write_text(json.dumps(checkpoint, indent=2) + "\n")

try:
    refresh_registry()
except Exception as exc:
    checkpoint_path.write_text(original_checkpoint_text)
    rollback_error = ""
    try:
        refresh_registry()
    except Exception as rollback_exc:
        rollback_error = (
            f" Rollback refresh also failed: {format_command_error(rollback_exc)}"
        )
    raise SystemExit(
        "refresh_registry.sh failed after updating guidance; restored checkpoints.json. "
        f"{format_command_error(exc)}{rollback_error}"
    )
PY

echo "Guidance updated for task: $TASK_SLUG"
if [ "$CLEAR_ACTIVE" = true ]; then
  echo "  cleared active guidance"
fi
if [ "$CLEAR_FOLLOW_UPS" = true ]; then
  echo "  cleared follow-up guidance"
fi
if [ -n "$SUMMARY" ]; then
  echo "  queued $MODE guidance: $SUMMARY"
fi
