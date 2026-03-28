#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
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
        "project_name": str(load_json(root_dir / ".campfire" / "project_context.json").get("project_name", root_dir.name)).strip() or root_dir.name,
        "task_root": str(load_json(root_dir / ".campfire" / "project_context.json").get("task_root", ".autonomous")).strip() or ".autonomous",
        "milestone_id": str(current.get("milestone_id", "")).strip(),
        "milestone_title": str(current.get("milestone_title", "")).strip(),
        "current_slice_id": str(current.get("slice_id", "")).strip(),
        "current_slice_title": str(current.get("slice_title", "")).strip(),
        "queued_count": len(queued),
        "stop_reason": str(last_run.get("stop_reason", "")).strip(),
    }


def active_task_slug(root_dir: Path) -> str:
    task = selected_task(root_dir)
    if not task:
        return ""
    if task["status"] == "in_progress" and task["current_slice_id"] and task["task_slug"]:
        return task["task_slug"]
    return ""


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


def emit_additional_context(event_name: str, text: str) -> int:
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": event_name,
                    "additionalContext": text,
                }
            }
        )
    )
    return 0


def stop_hook_dirs(root_dir: Path) -> tuple[Path, Path]:
    base = root_dir / ".campfire" / "monitoring" / "stop-hooks"
    return base / "events", base / "latest"


def record_stop_hook_event(
    root_dir: Path,
    task: dict,
    decision: str,
    summary: str,
    hook_input: dict,
    monitor_payload: dict | None = None,
    prompt: str = "",
) -> None:
    if not task or not task.get("task_slug"):
        return

    events_dir, latest_dir = stop_hook_dirs(root_dir)
    events_dir.mkdir(parents=True, exist_ok=True)
    latest_dir.mkdir(parents=True, exist_ok=True)

    now = datetime.now(timezone.utc)
    task_slug = str(task.get("task_slug", "")).strip()
    payload = {
        "recorded_at": now.isoformat(timespec="seconds").replace("+00:00", "Z"),
        "task_slug": task_slug,
        "status": str(task.get("status", "")).strip(),
        "phase": str(task.get("phase", "")).strip(),
        "run_mode": str(task.get("run_mode", "")).strip(),
        "milestone_id": str(task.get("milestone_id", "")).strip(),
        "milestone_title": str(task.get("milestone_title", "")).strip(),
        "current_slice_id": str(task.get("current_slice_id", "")).strip(),
        "current_slice_title": str(task.get("current_slice_title", "")).strip(),
        "queued_count": int(task.get("queued_count", 0) or 0),
        "last_stop_reason": str(task.get("stop_reason", "")).strip(),
        "decision": decision,
        "summary": summary,
        "hook_event_name": str(hook_input.get("hook_event_name", "")).strip(),
        "stop_hook_active": bool(hook_input.get("stop_hook_active")),
        "session_id": str(hook_input.get("session_id", "")).strip(),
        "turn_id": str(hook_input.get("turn_id", "")).strip(),
        "monitor_payload": monitor_payload or {},
        "prompt_preview": prompt[:280],
    }

    timestamp = now.strftime("%Y%m%dT%H%M%SZ")
    event_path = events_dir / f"{timestamp}-{task_slug}.json"
    latest_path = latest_dir / f"{task_slug}.json"
    serialized = json.dumps(payload, indent=2) + "\n"
    event_path.write_text(serialized)
    latest_path.write_text(serialized)


def refresh_active_task(root_dir: Path, source_name: str) -> int:
    task_slug = active_task_slug(root_dir)
    if not task_slug:
        return 0

    touch_script = resolve_script(
        root_dir,
        "scripts/touch_heartbeat.sh",
        "task-handoff-state/scripts/touch_heartbeat.sh",
    )
    refresh_script = resolve_script(
        root_dir,
        "scripts/refresh_registry.sh",
        "task-handoff-state/scripts/refresh_registry.sh",
    )
    if touch_script is None or refresh_script is None:
        return 0

    subprocess.run(
        [
            str(touch_script),
            "--root",
            str(root_dir),
            "--state",
            "active",
            "--source",
            source_name,
            "--summary",
            "Codex tool activity.",
            task_slug,
        ],
        capture_output=True,
        text=True,
    )
    subprocess.run(
        [str(refresh_script), "--root", str(root_dir)],
        capture_output=True,
        text=True,
    )
    return 0


def handle_session_start(root_dir: Path) -> int:
    task = selected_task(root_dir)
    if not task:
        return emit_additional_context(
            "SessionStart",
            "Campfire project detected.\n"
            f"project: {root_dir.name}\n"
            "task: none\n"
            'next_helper: ./scripts/new_task.sh "objective"',
        )

    milestone_text = task["milestone_id"]
    if task["milestone_id"] and task["milestone_title"]:
        milestone_text = f'{task["milestone_id"]} - {task["milestone_title"]}'

    lines = [
        "Campfire project detected.",
        f'project: {task["project_name"]}',
        f'task_root: {task["task_root"]}',
        f'task: {task["task_slug"]}',
        f'status: {task["status"]}',
    ]
    if task["phase"]:
        lines.append(f'phase: {task["phase"]}')
    if milestone_text:
        lines.append(f'milestone: {milestone_text}')
    if task["current_slice_title"]:
        lines.append(f'slice: {task["current_slice_title"]}')
    if task["stop_reason"]:
        lines.append(f'stop_reason: {task["stop_reason"]}')
    lines.append(f'next_helper: ./scripts/resume_task.sh {task["task_slug"]}')
    if task["status"] == "waiting_on_decision":
        lines.append("decision_boundary: stop and ask for the missing decision before implementing more work.")

    return emit_additional_context("SessionStart", "\n".join(lines))


def handle_user_prompt_submit(root_dir: Path) -> int:
    task = selected_task(root_dir)
    if not task:
        return 0
    if task["status"] not in {"waiting_on_decision", "blocked"}:
        return 0

    lines = [
        f'Campfire task {task["task_slug"]} is currently {task["status"]}.',
    ]
    if task["stop_reason"]:
        lines.append(f'stop_reason: {task["stop_reason"]}')
    if task["status"] == "waiting_on_decision":
        lines.append("Do not guess past the unresolved decision boundary; ask for the missing decision or keep the turn to inspection only.")
    else:
        lines.append("Do not assume the blocker is cleared; verify the blocker state before continuing implementation.")

    return emit_additional_context("UserPromptSubmit", "\n".join(lines))


def handle_post_tool_use(root_dir: Path, hook_input: dict) -> int:
    if str(hook_input.get("tool_name", "")).strip() != "Bash":
        return 0
    return refresh_active_task(root_dir, "codex-post-tool.sh")


def handle_stop(root_dir: Path, hook_input: dict) -> int:
    task = selected_task(root_dir)
    if not task:
        return 0

    if bool(hook_input.get("stop_hook_active")):
        record_stop_hook_event(
            root_dir,
            task,
            "noop_reentrant",
            "Stop hook was already active for this turn; Campfire did not continue.",
            hook_input,
        )
        return 0
    if task["run_mode"] != "rolling":
        record_stop_hook_event(
            root_dir,
            task,
            "noop_non_rolling",
            "Campfire did not continue because the selected task is not in rolling mode.",
            hook_input,
        )
        return 0
    if task["status"] not in CONTINUABLE_STATUSES:
        record_stop_hook_event(
            root_dir,
            task,
            "noop_non_continuable_status",
            f'Campfire did not continue because task status is {task["status"]}.',
            hook_input,
        )
        return 0
    if task["stop_reason"] in NON_CONTINUABLE_STOP_REASONS:
        record_stop_hook_event(
            root_dir,
            task,
            "noop_manual_pause",
            "Campfire did not continue because the task was manually paused.",
            hook_input,
        )
        return 0
    if not task["current_slice_id"] and task["queued_count"] <= 0:
        record_stop_hook_event(
            root_dir,
            task,
            "noop_no_safe_work",
            "Campfire did not continue because there is no active slice and no queued work.",
            hook_input,
        )
        return 0

    monitor_payload = load_monitor_payload(root_dir, task["task_slug"])
    if monitor_payload.get("recommended_action") != "allow":
        record_stop_hook_event(
            root_dir,
            task,
            f'noop_monitor_{monitor_payload.get("recommended_action", "unknown")}',
            str(monitor_payload.get("summary", "Campfire monitor did not allow continuation.")).strip(),
            hook_input,
            monitor_payload=monitor_payload,
        )
        return 0

    prompt = render_resume_prompt(root_dir, task["task_slug"])
    if not prompt:
        record_stop_hook_event(
            root_dir,
            task,
            "noop_missing_prompt",
            "Campfire did not continue because it could not render a rolling resume prompt.",
            hook_input,
            monitor_payload=monitor_payload,
        )
        return 0

    milestone_label = task["milestone_id"] or "current milestone"
    if task["milestone_id"] and task["milestone_title"]:
        milestone_label = f'{task["milestone_id"]} - {task["milestone_title"]}'
    summary = (
        f'Campfire continuing rolling task {task["task_slug"]} at {milestone_label}; '
        f'monitor verdict: {", ".join(monitor_payload.get("reason_codes", [])) or "allow"}.'
    )
    record_stop_hook_event(
        root_dir,
        task,
        "continue_rolling",
        summary,
        hook_input,
        monitor_payload=monitor_payload,
        prompt=prompt,
    )
    print(json.dumps({"decision": "block", "reason": prompt, "systemMessage": summary}))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Campfire Codex hook adapter")
    parser.add_argument("--root", default="", help="Workspace root override")
    args = parser.parse_args()

    try:
        hook_input = json.load(sys.stdin)
    except Exception:
        return 0

    if not isinstance(hook_input, dict):
        return 0

    root_dir = resolve_repo_root(args.root, hook_input)
    if root_dir is None:
        return 0
    if not ((root_dir / "campfire.toml").exists() or (root_dir / ".campfire").exists()):
        return 0

    event_name = str(hook_input.get("hook_event_name", "")).strip()
    if event_name == "SessionStart":
        return handle_session_start(root_dir)
    if event_name == "PostToolUse":
        return handle_post_tool_use(root_dir, hook_input)
    if event_name == "UserPromptSubmit":
        return handle_user_prompt_submit(root_dir)
    if event_name == "Stop":
        return handle_stop(root_dir, hook_input)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
