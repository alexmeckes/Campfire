#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


CONTINUABLE_STATUSES = {"in_progress", "ready", "validated"}
NON_CONTINUABLE_STOP_REASONS = {"manual_pause"}


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        payload = json.loads(path.read_text())
    except Exception:
        return {}
    return payload if isinstance(payload, dict) else {}


def resolve_repo_root(cli_root: str, hook_input: dict) -> Path | None:
    if cli_root:
        return Path(cli_root).resolve()

    cwd = str(hook_input.get("cwd", "")).strip()
    if cwd:
        try:
            return (
                Path(
                    subprocess.check_output(
                        ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                        text=True,
                    ).strip()
                ).resolve()
            )
        except Exception:
            return Path(cwd).resolve()

    return None


def resolve_script(root_dir: Path, relative_path: str, fallback_suffix: str) -> Path | None:
    primary = root_dir / relative_path
    if primary.exists():
        return primary

    env_root = (
        Path(str(os.environ.get("CAMPFIRE_SKILLS_ROOT", "")).strip()).resolve()
        if str(os.environ.get("CAMPFIRE_SKILLS_ROOT", "")).strip()
        else None
    )
    if env_root is None:
        codex_home = (
            Path(str(os.environ.get("CODEX_HOME", "")).strip()).expanduser()
            if str(os.environ.get("CODEX_HOME", "")).strip()
            else Path.home() / ".codex"
        )
        env_root = codex_home / "skills"

    fallback = env_root / fallback_suffix
    return fallback if fallback.exists() else None


def task_priority(task: dict) -> tuple[int, str]:
    status = str(task.get("status", "")).strip()
    priorities = {
        "in_progress": 0,
        "waiting_on_decision": 1,
        "blocked": 2,
        "ready": 3,
        "validated": 4,
        "completed": 5,
    }
    return priorities.get(status, 9), str(task.get("last_updated", ""))


def selected_task(root_dir: Path) -> dict:
    registry = load_json(root_dir / ".campfire" / "registry.json")
    tasks = registry.get("tasks", [])
    if not isinstance(tasks, list) or not tasks:
        return {}

    selected = sorted(tasks, key=task_priority)[0]
    task_dir = Path(str(selected.get("task_dir", "")).strip())
    task_context = load_json(task_dir / "task_context.json")
    current = task_context.get("current", {})
    if not isinstance(current, dict):
        current = {}
    last_run = task_context.get("last_run", {})
    if not isinstance(last_run, dict):
        last_run = {}
    queued = task_context.get("queued_milestones", [])
    if not isinstance(queued, list):
        queued = []

    return {
        "task_slug": str(selected.get("task_slug", "")).strip(),
        "status": str(selected.get("status", "unknown")).strip() or "unknown",
        "phase": str(selected.get("phase", "")).strip(),
        "task_dir": str(task_dir),
        "run_mode": str(task_context.get("run_mode", "")).strip(),
        "current_slice_id": str(current.get("slice_id", "")).strip(),
        "queued_count": len(queued),
        "stop_reason": str(last_run.get("stop_reason", "")).strip(),
    }


def load_monitor_payload(root_dir: Path, task_slug: str) -> dict:
    monitor_script = resolve_script(
        root_dir,
        "scripts/monitor_task.sh",
        "task-handoff-state/scripts/monitor_task.sh",
    )
    if monitor_script is None:
        return {}

    proc = subprocess.run(
        [str(monitor_script), "--root", str(root_dir), "--json", task_slug],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return {}
    try:
        payload = json.loads(proc.stdout)
    except Exception:
        return {}
    return payload if isinstance(payload, dict) else {}


def render_resume_prompt(root_dir: Path, task_slug: str) -> str:
    prompt_script = resolve_script(
        root_dir,
        "scripts/prompt_template_helper.sh",
        "task-handoff-state/scripts/prompt_template_helper.sh",
    )
    if prompt_script is None:
        return ""

    proc = subprocess.run(
        [
            str(prompt_script),
            "--root",
            str(root_dir),
            "--task-slug",
            task_slug,
            "rolling_resume",
        ],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Campfire Codex Stop hook")
    parser.add_argument("--root", default="", help="Workspace root override")
    args = parser.parse_args()

    try:
        hook_input = json.load(sys.stdin)
    except Exception:
        return 0

    if not isinstance(hook_input, dict):
        return 0
    if str(hook_input.get("hook_event_name", "")).strip() != "Stop":
        return 0
    if bool(hook_input.get("stop_hook_active")):
        return 0

    root_dir = resolve_repo_root(args.root, hook_input)
    if root_dir is None:
        return 0
    if not ((root_dir / "campfire.toml").exists() or (root_dir / ".campfire").exists()):
        return 0

    task = selected_task(root_dir)
    if not task:
        return 0
    if task["run_mode"] != "rolling":
        return 0
    if task["status"] not in CONTINUABLE_STATUSES:
        return 0
    if task["stop_reason"] in NON_CONTINUABLE_STOP_REASONS:
        return 0
    if not task["current_slice_id"] and task["queued_count"] <= 0:
        return 0

    monitor_payload = load_monitor_payload(root_dir, task["task_slug"])
    if monitor_payload.get("recommended_action") != "allow":
        return 0

    prompt = render_resume_prompt(root_dir, task["task_slug"])
    if not prompt:
        return 0

    print(json.dumps({"decision": "block", "reason": prompt}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
