#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    tomllib = None


SCHEMA_VERSION = 1


def now_utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def today_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text())
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def dump_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n")


def task_context_path(root_dir: Path, task_root: str, task_slug: str) -> Path:
    return root_dir / task_root / task_slug / "task_context.json"


def project_context_path(root_dir: Path) -> Path:
    return root_dir / ".campfire" / "project_context.json"


def improvement_backlog_path(root_dir: Path) -> Path:
    return root_dir / ".campfire" / "improvement_backlog.json"


def skill_inventory_path(root_dir: Path) -> Path:
    return root_dir / ".campfire" / "skill_inventory.json"


def extract_plan_objective(plan_path: Path) -> str:
    if not plan_path.exists():
        return ""
    text = plan_path.read_text()
    marker = "## Objective"
    if marker not in text:
        return ""
    after = text.split(marker, 1)[1].lstrip()
    lines: list[str] = []
    for line in after.splitlines():
        if line.startswith("## "):
            break
        if line.strip():
            lines.append(line.strip())
    return " ".join(lines).strip()


def normalize_queue(raw_queue: Any) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    if not isinstance(raw_queue, list):
        return entries
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
            entries.append(
                {
                    "milestone_id": milestone_id,
                    "milestone_title": milestone_title or milestone_id,
                }
            )
    return entries


def slugify(value: str, fallback: str) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    cleaned = re.sub(r"-{2,}", "-", cleaned)
    return cleaned or fallback


def improvement_candidate_output_path(root_dir: Path, task_root: str, task_slug: str, candidate_id: str) -> Path:
    return root_dir / task_root / task_slug / "findings" / f"{candidate_id}.json"


def status_to_milestone_status(task_status: str, is_current: bool) -> str:
    if not is_current:
        return "queued"
    if task_status == "completed":
        return "completed"
    if task_status == "validated":
        return "validated"
    if task_status in {"blocked", "waiting_on_decision", "in_progress"}:
        return task_status
    return "ready"


def status_to_slice_status(task_status: str) -> str:
    if task_status == "in_progress":
        return "in_progress"
    if task_status in {"validated", "completed"}:
        return "completed"
    if task_status in {"blocked", "waiting_on_decision"}:
        return task_status
    return "ready"


def load_config(root_dir: Path) -> dict[str, Any]:
    config_path = root_dir / "campfire.toml"
    config: dict[str, Any] = {
        "project_name": root_dir.name,
        "default_task_root": ".autonomous",
    }
    if not config_path.exists() or tomllib is None:
        return config
    try:
        loaded = tomllib.loads(config_path.read_text())
    except Exception:
        return config
    if isinstance(loaded, dict):
        config.update(loaded)
    return config


def db_path_for_root(root_dir: Path) -> Path:
    return root_dir / ".campfire" / "campfire.db"


def connect_db(root_dir: Path) -> sqlite3.Connection:
    db_path = db_path_for_root(root_dir)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    ensure_schema(conn)
    return conn


def ensure_column(conn: sqlite3.Connection, table: str, column: str, definition: str) -> None:
    rows = conn.execute(f"PRAGMA table_info({table})").fetchall()
    existing = {str(row["name"]) for row in rows}
    if column not in existing:
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS projects (
          id INTEGER PRIMARY KEY,
          root_path TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          task_root TEXT NOT NULL DEFAULT '.autonomous',
          config_path TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS tasks (
          id INTEGER PRIMARY KEY,
          project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
          slug TEXT NOT NULL,
          objective TEXT NOT NULL,
          status TEXT NOT NULL,
          phase TEXT NOT NULL,
          run_mode TEXT NOT NULL DEFAULT 'single_milestone',
          run_style TEXT NOT NULL DEFAULT 'bounded',
          current_milestone_key TEXT NOT NULL DEFAULT '',
          current_slice_key TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          completed_at TEXT,
          UNIQUE(project_id, slug)
        );

        CREATE TABLE IF NOT EXISTS milestones (
          id INTEGER PRIMARY KEY,
          task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
          milestone_key TEXT NOT NULL,
          title TEXT NOT NULL,
          status TEXT NOT NULL,
          ordinal INTEGER NOT NULL DEFAULT 0,
          acceptance_json TEXT NOT NULL DEFAULT '[]',
          dependencies_json TEXT NOT NULL DEFAULT '[]',
          notes TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE(task_id, milestone_key)
        );

        CREATE TABLE IF NOT EXISTS slices (
          id INTEGER PRIMARY KEY,
          task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
          milestone_id INTEGER REFERENCES milestones(id) ON DELETE SET NULL,
          slice_key TEXT NOT NULL,
          title TEXT NOT NULL,
          status TEXT NOT NULL,
          started_at TEXT,
          ended_at TEXT,
          summary TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE(task_id, slice_key)
        );

        CREATE TABLE IF NOT EXISTS queue_entries (
          id INTEGER PRIMARY KEY,
          task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
          milestone_key TEXT NOT NULL,
          milestone_title TEXT NOT NULL,
          position INTEGER NOT NULL,
          source TEXT NOT NULL DEFAULT 'sync',
          created_at TEXT NOT NULL,
          UNIQUE(task_id, position)
        );

        CREATE TABLE IF NOT EXISTS guidance_entries (
          id INTEGER PRIMARY KEY,
          task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
          active INTEGER NOT NULL DEFAULT 0,
          position INTEGER NOT NULL DEFAULT 0,
          mode TEXT NOT NULL DEFAULT '',
          summary TEXT NOT NULL DEFAULT '',
          details TEXT NOT NULL DEFAULT '',
          source TEXT NOT NULL DEFAULT 'operator',
          created_at TEXT NOT NULL,
          UNIQUE(task_id, active, position)
        );

        CREATE TABLE IF NOT EXISTS sessions (
          id INTEGER PRIMARY KEY,
          task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
          started_at TEXT NOT NULL,
          ended_at TEXT,
          stop_reason TEXT NOT NULL DEFAULT '',
          summary TEXT NOT NULL DEFAULT '',
          run_id TEXT NOT NULL DEFAULT '',
          parent_run_id TEXT NOT NULL DEFAULT '',
          lineage_kind TEXT NOT NULL DEFAULT '',
          branch_label TEXT NOT NULL DEFAULT '',
          UNIQUE(task_id, started_at)
        );

        CREATE TABLE IF NOT EXISTS events (
          id INTEGER PRIMARY KEY,
          task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
          session_id INTEGER REFERENCES sessions(id) ON DELETE CASCADE,
          milestone_key TEXT NOT NULL DEFAULT '',
          slice_key TEXT NOT NULL DEFAULT '',
          event_type TEXT NOT NULL,
          payload_json TEXT NOT NULL DEFAULT '{}',
          created_at TEXT NOT NULL,
          UNIQUE(task_id, session_id, event_type)
        );

        CREATE TABLE IF NOT EXISTS heartbeats (
          task_id INTEGER PRIMARY KEY REFERENCES tasks(id) ON DELETE CASCADE,
          session_id INTEGER REFERENCES sessions(id) ON DELETE SET NULL,
          state TEXT NOT NULL,
          session_started_at TEXT NOT NULL DEFAULT '',
          last_seen_at TEXT NOT NULL DEFAULT '',
          milestone_key TEXT NOT NULL DEFAULT '',
          milestone_title TEXT NOT NULL DEFAULT '',
          slice_key TEXT NOT NULL DEFAULT '',
          slice_title TEXT NOT NULL DEFAULT '',
          summary TEXT NOT NULL DEFAULT '',
          touched_path TEXT NOT NULL DEFAULT '',
          source TEXT NOT NULL DEFAULT ''
        );

        CREATE TABLE IF NOT EXISTS validations (
          id INTEGER PRIMARY KEY,
          task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
          validator_type TEXT NOT NULL,
          status TEXT NOT NULL,
          summary TEXT NOT NULL DEFAULT '',
          timestamp TEXT NOT NULL,
          artifact_path TEXT NOT NULL DEFAULT '',
          UNIQUE(task_id, validator_type, timestamp, summary)
        );

        CREATE TABLE IF NOT EXISTS artifacts (
          id INTEGER PRIMARY KEY,
          task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
          milestone_key TEXT NOT NULL DEFAULT '',
          path TEXT NOT NULL,
          kind TEXT NOT NULL DEFAULT '',
          reason TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          UNIQUE(task_id, path)
        );

        CREATE TABLE IF NOT EXISTS improvement_candidates (
          id INTEGER PRIMARY KEY,
          project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
          task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
          candidate_id TEXT NOT NULL,
          source_type TEXT NOT NULL DEFAULT '',
          source_task_slug TEXT NOT NULL DEFAULT '',
          source_milestone_key TEXT NOT NULL DEFAULT '',
          source_run_id TEXT NOT NULL DEFAULT '',
          title TEXT NOT NULL,
          category TEXT NOT NULL,
          scope TEXT NOT NULL,
          promotion_state TEXT NOT NULL DEFAULT 'proposed',
          problem TEXT NOT NULL DEFAULT '',
          why_not_script TEXT NOT NULL DEFAULT '',
          evidence_json TEXT NOT NULL DEFAULT '[]',
          trigger_pattern_json TEXT NOT NULL DEFAULT '[]',
          proposed_skill_name TEXT NOT NULL DEFAULT '',
          proposed_skill_purpose TEXT NOT NULL DEFAULT '',
          confidence TEXT NOT NULL DEFAULT '',
          next_action TEXT NOT NULL DEFAULT '',
          promoted_task_slug TEXT NOT NULL DEFAULT '',
          output_path TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE(project_id, candidate_id)
        );

        PRAGMA user_version = 1;
        """
    )
    ensure_column(conn, "sessions", "run_id", "TEXT NOT NULL DEFAULT ''")
    ensure_column(conn, "sessions", "parent_run_id", "TEXT NOT NULL DEFAULT ''")
    ensure_column(conn, "sessions", "lineage_kind", "TEXT NOT NULL DEFAULT ''")
    ensure_column(conn, "sessions", "branch_label", "TEXT NOT NULL DEFAULT ''")
    conn.commit()


def ensure_project(conn: sqlite3.Connection, root_dir: Path) -> sqlite3.Row:
    config = load_config(root_dir)
    now = now_utc()
    name = str(config.get("project_name", root_dir.name)).strip() or root_dir.name
    task_root = str(config.get("default_task_root", ".autonomous")).strip() or ".autonomous"
    config_path = str(root_dir / "campfire.toml") if (root_dir / "campfire.toml").exists() else ""

    conn.execute(
        """
        INSERT INTO projects(root_path, name, task_root, config_path, created_at, updated_at)
        VALUES(?, ?, ?, ?, ?, ?)
        ON CONFLICT(root_path) DO UPDATE SET
          name = excluded.name,
          task_root = excluded.task_root,
          config_path = excluded.config_path,
          updated_at = excluded.updated_at
        """,
        (str(root_dir), name, task_root, config_path, now, now),
    )
    conn.commit()
    return conn.execute(
        "SELECT * FROM projects WHERE root_path = ?",
        (str(root_dir),),
    ).fetchone()


def upsert_milestone(
    conn: sqlite3.Connection,
    task_id: int,
    milestone_key: str,
    title: str,
    status: str,
    ordinal: int,
    acceptance: list[Any],
    dependencies: list[Any],
) -> int:
    now = now_utc()
    conn.execute(
        """
        INSERT INTO milestones(
          task_id, milestone_key, title, status, ordinal, acceptance_json,
          dependencies_json, notes, created_at, updated_at
        )
        VALUES(?, ?, ?, ?, ?, ?, ?, '', ?, ?)
        ON CONFLICT(task_id, milestone_key) DO UPDATE SET
          title = excluded.title,
          status = excluded.status,
          ordinal = excluded.ordinal,
          acceptance_json = excluded.acceptance_json,
          dependencies_json = excluded.dependencies_json,
          updated_at = excluded.updated_at
        """,
        (
            task_id,
            milestone_key,
            title,
            status,
            ordinal,
            json.dumps(acceptance or []),
            json.dumps(dependencies or []),
            now,
            now,
        ),
    )
    row = conn.execute(
        "SELECT id FROM milestones WHERE task_id = ? AND milestone_key = ?",
        (task_id, milestone_key),
    ).fetchone()
    if row is None:  # pragma: no cover
        raise RuntimeError(f"Milestone upsert failed for {milestone_key}")
    return int(row["id"])


def sync_task(conn: sqlite3.Connection, root_dir: Path, task_slug: str) -> dict[str, Any]:
    project = ensure_project(conn, root_dir)
    task_root = str(project["task_root"])
    task_dir = root_dir / task_root / task_slug
    checkpoint_path = task_dir / "checkpoints.json"
    if not checkpoint_path.exists():
        raise SystemExit(f"Task checkpoints missing: {checkpoint_path}")

    checkpoint = load_json(checkpoint_path)
    heartbeat = load_json(task_dir / "heartbeat.json")
    artifacts_manifest = load_json(task_dir / "artifacts.json")
    objective = str(checkpoint.get("objective", "")).strip() or extract_plan_objective(task_dir / "plan.md")
    if not objective:
        objective = task_slug

    now = now_utc()
    status = str(checkpoint.get("status", "ready")).strip() or "ready"
    phase = str(checkpoint.get("phase", "planning")).strip() or "planning"
    execution = checkpoint.get("execution", {})
    if not isinstance(execution, dict):
        execution = {}
    current = checkpoint.get("current", {})
    if not isinstance(current, dict):
        current = {}
    queue = normalize_queue(execution.get("queued_milestones", []))
    guidance = normalize_guidance(checkpoint.get("guidance", {}))

    run_mode = str(execution.get("mode", "single_milestone")).strip() or "single_milestone"
    run_style = str(execution.get("run_style", "bounded")).strip() or "bounded"
    current_milestone_key = str(current.get("milestone_id", "")).strip()
    current_slice_key = str(current.get("slice_id", "")).strip()

    conn.execute(
        """
        INSERT INTO tasks(
          project_id, slug, objective, status, phase, run_mode, run_style,
          current_milestone_key, current_slice_key, created_at, updated_at, completed_at
        )
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(project_id, slug) DO UPDATE SET
          objective = excluded.objective,
          status = excluded.status,
          phase = excluded.phase,
          run_mode = excluded.run_mode,
          run_style = excluded.run_style,
          current_milestone_key = excluded.current_milestone_key,
          current_slice_key = excluded.current_slice_key,
          updated_at = excluded.updated_at,
          completed_at = excluded.completed_at
        """,
        (
            int(project["id"]),
            task_slug,
            objective,
            status,
            phase,
            run_mode,
            run_style,
            current_milestone_key,
            current_slice_key,
            now,
            now,
            now if status == "completed" else None,
        ),
    )
    task_row = conn.execute(
        "SELECT * FROM tasks WHERE project_id = ? AND slug = ?",
        (int(project["id"]), task_slug),
    ).fetchone()
    if task_row is None:  # pragma: no cover
        raise RuntimeError(f"Task upsert failed for {task_slug}")
    task_id = int(task_row["id"])

    current_milestone_id: int | None = None
    if current_milestone_key:
        current_milestone_id = upsert_milestone(
            conn,
            task_id,
            current_milestone_key,
            str(current.get("milestone_title", "")).strip() or current_milestone_key,
            status_to_milestone_status(status, True),
            0,
            current.get("acceptance_criteria", []) if isinstance(current.get("acceptance_criteria"), list) else [],
            current.get("dependencies", []) if isinstance(current.get("dependencies"), list) else [],
        )

    conn.execute("DELETE FROM queue_entries WHERE task_id = ?", (task_id,))
    for index, entry in enumerate(queue, start=1):
        upsert_milestone(
            conn,
            task_id,
            entry["milestone_id"],
            entry["milestone_title"],
            "queued",
            index,
            [],
            [],
        )
        conn.execute(
            """
            INSERT INTO queue_entries(task_id, milestone_key, milestone_title, position, source, created_at)
            VALUES(?, ?, ?, ?, 'sync', ?)
            """,
            (task_id, entry["milestone_id"], entry["milestone_title"], index, now),
        )

    conn.execute("DELETE FROM guidance_entries WHERE task_id = ?", (task_id,))
    active_guidance = guidance.get("active")
    if isinstance(active_guidance, dict):
        conn.execute(
            """
            INSERT INTO guidance_entries(
              task_id, active, position, mode, summary, details, source, created_at
            )
            VALUES(?, 1, 0, ?, ?, ?, ?, ?)
            """,
            (
                task_id,
                active_guidance.get("mode", "interrupt_now"),
                active_guidance.get("summary", ""),
                active_guidance.get("details", ""),
                active_guidance.get("source", "operator"),
                active_guidance.get("created_at", "") or now,
            ),
        )
    for index, follow_up in enumerate(guidance.get("follow_ups", []), start=1):
        if not isinstance(follow_up, dict):
            continue
        conn.execute(
            """
            INSERT INTO guidance_entries(
              task_id, active, position, mode, summary, details, source, created_at
            )
            VALUES(?, 0, ?, ?, ?, ?, ?, ?)
            """,
            (
                task_id,
                index,
                follow_up.get("mode", "next_boundary"),
                follow_up.get("summary", ""),
                follow_up.get("details", ""),
                follow_up.get("source", "operator"),
                follow_up.get("created_at", "") or now,
            ),
        )

    if current_slice_key:
        conn.execute(
            """
            INSERT INTO slices(
              task_id, milestone_id, slice_key, title, status, started_at, ended_at,
              summary, created_at, updated_at
            )
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(task_id, slice_key) DO UPDATE SET
              milestone_id = excluded.milestone_id,
              title = excluded.title,
              status = excluded.status,
              started_at = excluded.started_at,
              ended_at = excluded.ended_at,
              summary = excluded.summary,
              updated_at = excluded.updated_at
            """,
            (
                task_id,
                current_milestone_id,
                current_slice_key,
                str(current.get("slice_title", "")).strip() or current_slice_key,
                status_to_slice_status(status),
                str(checkpoint.get("last_run", {}).get("started_at", "")).strip() or str(heartbeat.get("session_started_at", "")).strip() or None,
                str(checkpoint.get("last_run", {}).get("ended_at", "")).strip() or None,
                str(checkpoint.get("last_run", {}).get("summary", "")).strip(),
                now,
                now,
            ),
        )

    last_run = checkpoint.get("last_run", {})
    if not isinstance(last_run, dict):
        last_run = {}
    lineage = normalize_lineage(last_run.get("lineage", {}))
    session_started_at = str(last_run.get("started_at", "")).strip() or str(heartbeat.get("session_started_at", "")).strip()
    session_id: int | None = None
    if session_started_at:
        run_id = str(last_run.get("run_id", "")).strip() or session_started_at
        conn.execute(
            """
            INSERT INTO sessions(
              task_id, started_at, ended_at, stop_reason, summary,
              run_id, parent_run_id, lineage_kind, branch_label
            )
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(task_id, started_at) DO UPDATE SET
              ended_at = excluded.ended_at,
              stop_reason = excluded.stop_reason,
              summary = excluded.summary,
              run_id = excluded.run_id,
              parent_run_id = excluded.parent_run_id,
              lineage_kind = excluded.lineage_kind,
              branch_label = excluded.branch_label
            """,
            (
                task_id,
                session_started_at,
                str(last_run.get("ended_at", "")).strip() or None,
                str(last_run.get("stop_reason", "")).strip(),
                str(last_run.get("summary", "")).strip(),
                run_id,
                lineage["parent_run_id"],
                lineage["kind"],
                lineage["branch_label"],
            ),
        )
        row = conn.execute(
            "SELECT id FROM sessions WHERE task_id = ? AND started_at = ?",
            (task_id, session_started_at),
        ).fetchone()
        session_id = int(row["id"]) if row else None

    events = last_run.get("events", [])
    if not isinstance(events, list):
        events = []
    event_timestamp = (
        str(last_run.get("ended_at", "")).strip()
        or session_started_at
        or now
    )
    for event_type in events:
        if not isinstance(event_type, str) or not event_type.strip():
            continue
        conn.execute(
            """
            INSERT OR IGNORE INTO events(
              task_id, session_id, milestone_key, slice_key, event_type, payload_json, created_at
            )
            VALUES(?, ?, ?, ?, ?, ?, ?)
            """,
            (
                task_id,
                session_id,
                current_milestone_key,
                current_slice_key,
                event_type.strip(),
                "{}",
                event_timestamp,
            ),
        )

    if heartbeat:
        conn.execute(
            """
            INSERT INTO heartbeats(
              task_id, session_id, state, session_started_at, last_seen_at,
              milestone_key, milestone_title, slice_key, slice_title, summary,
              touched_path, source
            )
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(task_id) DO UPDATE SET
              session_id = excluded.session_id,
              state = excluded.state,
              session_started_at = excluded.session_started_at,
              last_seen_at = excluded.last_seen_at,
              milestone_key = excluded.milestone_key,
              milestone_title = excluded.milestone_title,
              slice_key = excluded.slice_key,
              slice_title = excluded.slice_title,
              summary = excluded.summary,
              touched_path = excluded.touched_path,
              source = excluded.source
            """,
            (
                task_id,
                session_id,
                str(heartbeat.get("state", "")).strip() or "idle",
                str(heartbeat.get("session_started_at", "")).strip(),
                str(heartbeat.get("last_seen_at", "")).strip(),
                str(heartbeat.get("milestone_id", "")).strip(),
                str(heartbeat.get("milestone_title", "")).strip(),
                str(heartbeat.get("slice_id", "")).strip(),
                str(heartbeat.get("slice_title", "")).strip(),
                str(heartbeat.get("summary", "")).strip(),
                str(heartbeat.get("touched_path", "")).strip(),
                str(heartbeat.get("source", "")).strip(),
            ),
        )

    validations = checkpoint.get("validation", [])
    if not isinstance(validations, list):
        validations = []
    for item in validations:
        if not isinstance(item, dict):
            continue
        validator_type = str(item.get("type", "")).strip() or "unknown"
        timestamp = str(item.get("timestamp", "")).strip() or now
        summary = str(item.get("summary", "")).strip()
        artifact_path = str(item.get("artifact_path", "")).strip()
        validation_status = str(item.get("status", "")).strip() or "passed"
        conn.execute(
            """
            INSERT OR IGNORE INTO validations(
              task_id, validator_type, status, summary, timestamp, artifact_path
            )
            VALUES(?, ?, ?, ?, ?, ?)
            """,
            (
                task_id,
                validator_type,
                validation_status,
                summary,
                timestamp,
                artifact_path,
            ),
        )

    artifacts = artifacts_manifest.get("artifacts", [])
    if isinstance(artifacts, list):
        for artifact in artifacts:
            if not isinstance(artifact, dict):
                continue
            artifact_path = str(artifact.get("path", "")).strip()
            if not artifact_path:
                continue
            conn.execute(
                """
                INSERT OR IGNORE INTO artifacts(
                  task_id, milestone_key, path, kind, reason, created_at
                )
                VALUES(?, ?, ?, ?, ?, ?)
                """,
                (
                    task_id,
                    str(artifact.get("milestone_id", "")).strip(),
                    artifact_path,
                    str(artifact.get("kind", "")).strip(),
                    str(artifact.get("reason", "")).strip(),
                    str(artifact.get("timestamp", "")).strip() or now,
                ),
            )

    conn.commit()
    return {
        "task_slug": task_slug,
        "task_dir": str(task_dir),
        "status": status,
        "queue_count": len(queue),
        "db_path": str(db_path_for_root(root_dir)),
    }


def sync_all(conn: sqlite3.Connection, root_dir: Path) -> list[dict[str, Any]]:
    project = ensure_project(conn, root_dir)
    task_root = root_dir / str(project["task_root"])
    if not task_root.exists():
        return []
    payloads: list[dict[str, Any]] = []
    for task_dir in sorted(p for p in task_root.iterdir() if p.is_dir()):
        if not (task_dir / "checkpoints.json").exists():
            continue
        payloads.append(sync_task(conn, root_dir, task_dir.name))
    return payloads


def lookup_task_row(
    conn: sqlite3.Connection,
    project_id: int,
    task_slug: str,
) -> sqlite3.Row | None:
    return conn.execute(
        """
        SELECT id, slug, current_milestone_key, current_slice_key, status
        FROM tasks
        WHERE project_id = ? AND slug = ?
        """,
        (project_id, task_slug),
    ).fetchone()


def parse_json_array(value: str) -> list[Any]:
    try:
        payload = json.loads(value)
    except Exception:
        return []
    return payload if isinstance(payload, list) else []


def normalize_guidance_mode(value: Any, fallback: str) -> str:
    text = str(value or "").strip().lower()
    aliases = {
        "interrupt_now": "interrupt_now",
        "interrupt-now": "interrupt_now",
        "interrupt": "interrupt_now",
        "urgent": "interrupt_now",
        "immediate": "interrupt_now",
        "next_boundary": "next_boundary",
        "next-boundary": "next_boundary",
        "boundary": "next_boundary",
        "follow_up": "next_boundary",
        "follow-up": "next_boundary",
    }
    return aliases.get(text, fallback)


def normalize_guidance_entry(raw_entry: Any, *, default_mode: str) -> dict[str, str] | None:
    if isinstance(raw_entry, str):
        summary = raw_entry.strip()
        details = ""
        source = "operator"
        created_at = ""
        mode = default_mode
    elif isinstance(raw_entry, dict):
        summary = str(
            raw_entry.get("summary")
            or raw_entry.get("title")
            or raw_entry.get("text")
            or ""
        ).strip()
        details = str(
            raw_entry.get("details")
            or raw_entry.get("description")
            or raw_entry.get("note")
            or ""
        ).strip()
        source = str(raw_entry.get("source", "operator")).strip() or "operator"
        created_at = str(
            raw_entry.get("created_at")
            or raw_entry.get("queued_at")
            or ""
        ).strip()
        mode = normalize_guidance_mode(raw_entry.get("mode", default_mode), default_mode)
    else:
        return None

    if not summary:
        return None

    return {
        "mode": mode,
        "summary": summary,
        "details": details,
        "source": source,
        "created_at": created_at,
    }


def normalize_guidance(raw_guidance: Any) -> dict[str, Any]:
    if not isinstance(raw_guidance, dict):
        return {"active": None, "follow_ups": []}

    active = normalize_guidance_entry(
        raw_guidance.get("active"),
        default_mode="interrupt_now",
    )
    follow_up_key = "follow_ups"
    if follow_up_key not in raw_guidance and isinstance(raw_guidance.get("queued"), list):
        follow_up_key = "queued"
    follow_ups: list[dict[str, str]] = []
    for raw_entry in raw_guidance.get(follow_up_key, []):
        entry = normalize_guidance_entry(raw_entry, default_mode="next_boundary")
        if entry is not None:
            follow_ups.append(entry)
    return {
        "active": active,
        "follow_ups": follow_ups,
    }


def guidance_payload_from_rows(rows: list[sqlite3.Row]) -> dict[str, Any]:
    active: dict[str, Any] | None = None
    follow_ups: list[dict[str, Any]] = []
    for row in rows:
        entry = {
            "mode": row["mode"] or "",
            "summary": row["summary"] or "",
            "details": row["details"] or "",
            "source": row["source"] or "",
            "created_at": row["created_at"] or "",
        }
        if int(row["active"] or 0):
            active = entry
        else:
            entry["position"] = int(row["position"] or 0)
            follow_ups.append(entry)
    return {
        "active": active,
        "follow_ups": follow_ups,
    }


def normalize_lineage_kind(value: Any) -> str:
    text = str(value or "").strip().lower()
    aliases = {
        "retry": "retry",
        "course_correction": "course_correction",
        "course-correction": "course_correction",
        "benchmark_repro": "benchmark_repro",
        "benchmark-repro": "benchmark_repro",
        "repro": "benchmark_repro",
    }
    return aliases.get(text, "")


def normalize_lineage(raw_lineage: Any) -> dict[str, str]:
    if not isinstance(raw_lineage, dict):
        return {
            "parent_run_id": "",
            "kind": "",
            "branch_label": "",
        }
    return {
        "parent_run_id": str(raw_lineage.get("parent_run_id", "")).strip(),
        "kind": normalize_lineage_kind(raw_lineage.get("kind", "")),
        "branch_label": str(raw_lineage.get("branch_label", "")).strip(),
    }


def upsert_improvement_candidate(
    conn: sqlite3.Connection,
    root_dir: Path,
    *,
    task_slug: str,
    candidate_id: str,
    source_type: str,
    source_milestone_key: str,
    source_run_id: str,
    title: str,
    category: str,
    scope: str,
    promotion_state: str,
    problem: str,
    why_not_script: str,
    evidence: list[str],
    trigger_pattern: list[str],
    proposed_skill_name: str,
    proposed_skill_purpose: str,
    confidence: str,
    next_action: str,
    promoted_task_slug: str,
    output_path: str,
) -> dict[str, Any]:
    project = ensure_project(conn, root_dir)
    task_root = str(project["task_root"])
    task_row: sqlite3.Row | None = None
    if task_slug:
        task_path = root_dir / task_root / task_slug / "checkpoints.json"
        if task_path.exists():
            sync_task(conn, root_dir, task_slug)
        task_row = lookup_task_row(conn, int(project["id"]), task_slug)
        if task_row is None:
            raise SystemExit(f"Task not present in DB: {task_slug}")

    now = now_utc()
    if not candidate_id:
        candidate_id = f"{today_utc()}-{slugify(title, 'candidate')}"
    if not output_path and task_slug:
        output_path = str(
            improvement_candidate_output_path(
                root_dir,
                task_root,
                task_slug,
                candidate_id,
            )
        )

    conn.execute(
        """
        INSERT INTO improvement_candidates(
          project_id, task_id, candidate_id, source_type, source_task_slug,
          source_milestone_key, source_run_id, title, category, scope, promotion_state,
          problem, why_not_script, evidence_json, trigger_pattern_json,
          proposed_skill_name, proposed_skill_purpose, confidence, next_action,
          promoted_task_slug, output_path, created_at, updated_at
        )
        VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(project_id, candidate_id) DO UPDATE SET
          task_id = excluded.task_id,
          source_type = excluded.source_type,
          source_task_slug = excluded.source_task_slug,
          source_milestone_key = excluded.source_milestone_key,
          source_run_id = excluded.source_run_id,
          title = excluded.title,
          category = excluded.category,
          scope = excluded.scope,
          promotion_state = excluded.promotion_state,
          problem = excluded.problem,
          why_not_script = excluded.why_not_script,
          evidence_json = excluded.evidence_json,
          trigger_pattern_json = excluded.trigger_pattern_json,
          proposed_skill_name = excluded.proposed_skill_name,
          proposed_skill_purpose = excluded.proposed_skill_purpose,
          confidence = excluded.confidence,
          next_action = excluded.next_action,
          promoted_task_slug = excluded.promoted_task_slug,
          output_path = excluded.output_path,
          updated_at = excluded.updated_at
        """,
        (
            int(project["id"]),
            int(task_row["id"]) if task_row else None,
            candidate_id,
            source_type,
            task_slug,
            source_milestone_key,
            source_run_id,
            title,
            category,
            scope,
            promotion_state,
            problem,
            why_not_script,
            json.dumps(evidence),
            json.dumps(trigger_pattern),
            proposed_skill_name,
            proposed_skill_purpose,
            confidence,
            next_action,
            promoted_task_slug,
            output_path,
            now,
            now,
        ),
    )
    conn.commit()

    row = conn.execute(
        """
        SELECT *
        FROM improvement_candidates
        WHERE project_id = ? AND candidate_id = ?
        """,
        (int(project["id"]), candidate_id),
    ).fetchone()
    if row is None:  # pragma: no cover
        raise RuntimeError(f"Improvement candidate upsert failed: {candidate_id}")

    payload = improvement_candidate_payload(row)
    if output_path:
        dump_json(Path(output_path), payload)
    return payload


def improvement_candidate_payload(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "candidate_id": row["candidate_id"],
        "source": {
            "type": row["source_type"],
            "task_slug": row["source_task_slug"],
            "milestone_id": row["source_milestone_key"],
            "run_id": row["source_run_id"],
        },
        "title": row["title"],
        "category": row["category"],
        "scope": row["scope"],
        "promotion_state": row["promotion_state"],
        "problem": row["problem"],
        "why_not_script": row["why_not_script"],
        "evidence": parse_json_array(row["evidence_json"]),
        "trigger_pattern": parse_json_array(row["trigger_pattern_json"]),
        "proposed_skill": {
            "name": row["proposed_skill_name"],
            "purpose": row["proposed_skill_purpose"],
        },
        "confidence": row["confidence"],
        "next_action": row["next_action"],
        "promoted_task_slug": row["promoted_task_slug"],
        "output_path": row["output_path"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def build_improvement_backlog(conn: sqlite3.Connection, root_dir: Path) -> dict[str, Any]:
    project = ensure_project(conn, root_dir)
    rows = conn.execute(
        """
        SELECT *
        FROM improvement_candidates
        WHERE project_id = ?
        ORDER BY updated_at DESC, candidate_id ASC
        """,
        (int(project["id"]),),
    ).fetchall()
    candidates = [improvement_candidate_payload(row) for row in rows]
    state_counts: dict[str, int] = {}
    category_counts: dict[str, int] = {}
    for candidate in candidates:
        promotion_state = str(candidate["promotion_state"])
        category = str(candidate["category"])
        state_counts[promotion_state] = state_counts.get(promotion_state, 0) + 1
        category_counts[category] = category_counts.get(category, 0) + 1
    return {
        "generated_at": now_utc(),
        "root": str(root_dir),
        "db_path": str(db_path_for_root(root_dir)),
        "candidate_count": len(candidates),
        "counts": {
            "by_promotion_state": state_counts,
            "by_category": category_counts,
        },
        "candidates": candidates,
    }


def render_improvement_backlog(
    conn: sqlite3.Connection,
    root_dir: Path,
    output_path: Path | None = None,
) -> Path:
    if output_path is None:
        output_path = improvement_backlog_path(root_dir)
    dump_json(output_path, build_improvement_backlog(conn, root_dir))
    return output_path


def update_improvement_candidate_promotion(
    conn: sqlite3.Connection,
    root_dir: Path,
    candidate_id: str,
    promotion_state: str,
    promoted_task_slug: str,
) -> dict[str, Any]:
    project = ensure_project(conn, root_dir)
    now = now_utc()
    cursor = conn.execute(
        """
        UPDATE improvement_candidates
        SET promotion_state = ?,
            promoted_task_slug = ?,
            updated_at = ?
        WHERE project_id = ? AND candidate_id = ?
        """,
        (
            promotion_state,
            promoted_task_slug,
            now,
            int(project["id"]),
            candidate_id,
        ),
    )
    if cursor.rowcount == 0:
        raise SystemExit(f"Improvement candidate not found: {candidate_id}")
    conn.commit()
    row = conn.execute(
        """
        SELECT *
        FROM improvement_candidates
        WHERE project_id = ? AND candidate_id = ?
        """,
        (int(project["id"]), candidate_id),
    ).fetchone()
    if row is None:  # pragma: no cover
        raise RuntimeError(f"Improvement candidate lookup failed: {candidate_id}")
    payload = improvement_candidate_payload(row)
    output_path = str(row["output_path"]).strip()
    if output_path:
        dump_json(Path(output_path), payload)
    return payload


def discover_skill_entries(root_dir: Path, task_root: str) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []

    def candidate_metadata(candidate_path: Path) -> dict[str, str]:
        if not candidate_path.exists():
            return {"candidate_id": "", "promotion_state": ""}
        payload = load_json(candidate_path)
        return {
            "candidate_id": str(
                payload.get("candidate_id")
                or payload.get("id")
                or ""
            ).strip(),
            "promotion_state": str(payload.get("promotion_state", "")).strip(),
        }

    def install_target(scope: str, skill_name: str, task_slug: str = "") -> str:
        if scope == "core":
            return skill_name
        if scope == "campfire_generated_core":
            return f"generated--{skill_name}"
        if scope == "repo_local_generated":
            return f"repo-local--{skill_name}"
        if scope == "task_local_generated":
            return f"{slugify(task_slug, 'task')}--{skill_name}"
        return skill_name

    def append_entry(skill_dir: Path, scope: str, *, task_slug: str = "") -> None:
        skill_file = skill_dir / "SKILL.md"
        if not skill_file.exists():
            return
        candidate_path = skill_dir / "skill_candidate.json"
        metadata = candidate_metadata(candidate_path)
        entries.append(
            {
                "skill_name": skill_dir.name,
                "scope": scope,
                "task_slug": task_slug,
                "package_name": install_target(scope, skill_dir.name, task_slug),
                "source_dir": str(skill_dir),
                "skill_path": str(skill_file),
                "candidate_path": str(candidate_path) if candidate_path.exists() else "",
                "candidate_id": metadata["candidate_id"],
                "promotion_state": metadata["promotion_state"],
                "has_agent_config": (skill_dir / "agents" / "openai.yaml").exists(),
                "installable": True,
            }
        )

    core_root = root_dir / "skills"
    if core_root.exists():
        for skill_dir in sorted(p for p in core_root.iterdir() if p.is_dir() and p.name != "generated"):
            append_entry(skill_dir, "core")
        generated_core_root = core_root / "generated"
        if generated_core_root.exists():
            for skill_dir in sorted(p for p in generated_core_root.iterdir() if p.is_dir()):
                append_entry(skill_dir, "campfire_generated_core")

    repo_generated_root = root_dir / ".campfire" / "generated-skills"
    if repo_generated_root.exists():
        for skill_dir in sorted(p for p in repo_generated_root.iterdir() if p.is_dir()):
            append_entry(skill_dir, "repo_local_generated")

    task_root_path = root_dir / task_root
    if task_root_path.exists():
        for task_dir in sorted(p for p in task_root_path.iterdir() if p.is_dir()):
            generated_root = task_dir / "generated-skills"
            if not generated_root.exists():
                continue
            for skill_dir in sorted(p for p in generated_root.iterdir() if p.is_dir()):
                append_entry(skill_dir, "task_local_generated", task_slug=task_dir.name)

    return entries


def build_skill_inventory(root_dir: Path, task_root: str) -> dict[str, Any]:
    skills = discover_skill_entries(root_dir, task_root)
    counts: dict[str, int] = {}
    for entry in skills:
        scope = str(entry.get("scope", ""))
        counts[scope] = counts.get(scope, 0) + 1
    return {
        "generated_at": now_utc(),
        "root": str(root_dir),
        "manifest_version": 1,
        "task_root": task_root,
        "package_count": len(skills),
        "counts": {
            "by_scope": counts,
        },
        "skills": skills,
    }


def render_skill_inventory(root_dir: Path, task_root: str, output_path: Path | None = None) -> Path:
    if output_path is None:
        output_path = skill_inventory_path(root_dir)
    dump_json(output_path, build_skill_inventory(root_dir, task_root))
    return output_path


def build_project_context(conn: sqlite3.Connection, root_dir: Path) -> dict[str, Any]:
    project = ensure_project(conn, root_dir)
    config = load_config(root_dir)
    skill_inventory = build_skill_inventory(root_dir, str(project["task_root"]))
    task_rows = conn.execute(
        """
        SELECT status, COUNT(*) AS count
        FROM tasks
        WHERE project_id = ?
        GROUP BY status
        """,
        (int(project["id"]),),
    ).fetchall()
    status_counts = {str(row["status"]): int(row["count"]) for row in task_rows}
    improvement_rows = conn.execute(
        """
        SELECT promotion_state, COUNT(*) AS count
        FROM improvement_candidates
        WHERE project_id = ?
        GROUP BY promotion_state
        """,
        (int(project["id"]),),
    ).fetchall()
    improvement_counts = {
        str(row["promotion_state"]): int(row["count"])
        for row in improvement_rows
    }
    validators = config.get("validators", [])
    return {
        "generated_at": now_utc(),
        "root": str(root_dir),
        "project_name": str(project["name"]),
        "task_root": str(project["task_root"]),
        "db_path": str(db_path_for_root(root_dir)),
        "improvement_backlog_path": str(improvement_backlog_path(root_dir)),
        "skill_inventory_path": str(skill_inventory_path(root_dir)),
        "source_docs": list(config.get("source_docs", {}).get("priority", []))
        if isinstance(config.get("source_docs"), dict)
        else [],
        "default_skills": list(config.get("skills", {}).get("default", []))
        if isinstance(config.get("skills"), dict)
        else [],
        "validators": [
            {
                "id": str(item.get("id", "")).strip(),
                "kind": str(item.get("kind", "")).strip(),
                "label": str(item.get("label", "")).strip(),
            }
            for item in validators
            if isinstance(item, dict) and str(item.get("id", "")).strip()
        ],
        "task_counts": {
            "total": sum(status_counts.values()),
            "by_status": status_counts,
        },
        "improvement_counts": {
            "total": sum(improvement_counts.values()),
            "by_promotion_state": improvement_counts,
        },
        "skill_counts": skill_inventory.get("counts", {}),
        "discoverable_skills": {
            "repo_local_generated": [
                entry
                for entry in skill_inventory.get("skills", [])
                if str(entry.get("scope", "")) == "repo_local_generated"
            ],
            "campfire_generated_core": [
                entry
                for entry in skill_inventory.get("skills", [])
                if str(entry.get("scope", "")) == "campfire_generated_core"
            ],
        },
        "task_defaults": config.get("task_defaults", {})
        if isinstance(config.get("task_defaults"), dict)
        else {},
    }


def build_task_context(conn: sqlite3.Connection, root_dir: Path, task_slug: str) -> dict[str, Any]:
    project = ensure_project(conn, root_dir)
    config = load_config(root_dir)
    task_root = str(project["task_root"])
    skill_inventory = build_skill_inventory(root_dir, task_root)
    row = conn.execute(
        """
        SELECT
          t.id,
          t.slug,
          t.objective,
          t.status,
          t.phase,
          t.run_mode,
          t.run_style,
          t.current_milestone_key,
          t.current_slice_key,
          t.updated_at,
          m.title AS current_milestone_title,
          s.title AS current_slice_title,
          hb.state AS heartbeat_state,
          hb.last_seen_at AS heartbeat_last_seen_at,
          hb.session_started_at AS heartbeat_session_started_at,
          hb.summary AS heartbeat_summary,
          hb.touched_path AS heartbeat_touched_path,
          sess.run_id AS last_run_id,
          sess.parent_run_id AS last_parent_run_id,
          sess.lineage_kind AS last_lineage_kind,
          sess.branch_label AS last_branch_label,
          sess.stop_reason AS last_stop_reason,
          sess.started_at AS last_started_at,
          sess.ended_at AS last_ended_at,
          sess.summary AS last_summary
        FROM tasks t
        LEFT JOIN milestones m
          ON m.task_id = t.id AND m.milestone_key = t.current_milestone_key
        LEFT JOIN slices s
          ON s.task_id = t.id AND s.slice_key = t.current_slice_key
        LEFT JOIN heartbeats hb
          ON hb.task_id = t.id
        LEFT JOIN sessions sess
          ON sess.id = (
            SELECT id FROM sessions latest
            WHERE latest.task_id = t.id
            ORDER BY latest.started_at DESC
            LIMIT 1
          )
        WHERE t.project_id = ? AND t.slug = ?
        """,
        (int(project["id"]), task_slug),
    ).fetchone()
    if row is None:
        raise SystemExit(f"Task not present in DB: {task_slug}")

    queue_rows = conn.execute(
        """
        SELECT milestone_key, milestone_title, position
        FROM queue_entries
        WHERE task_id = ?
        ORDER BY position ASC
        """,
        (int(row["id"]),),
    ).fetchall()
    validation_rows = conn.execute(
        """
        SELECT validator_type, status, summary, timestamp, artifact_path
        FROM validations
        WHERE task_id = ?
        ORDER BY timestamp DESC
        LIMIT 5
        """,
        (int(row["id"]),),
    ).fetchall()
    artifact_rows = conn.execute(
        """
        SELECT milestone_key, path, kind, reason, created_at
        FROM artifacts
        WHERE task_id = ?
        ORDER BY created_at DESC
        LIMIT 10
        """,
        (int(row["id"]),),
    ).fetchall()
    improvement_rows = conn.execute(
        """
        SELECT *
        FROM improvement_candidates
        WHERE project_id = ? AND source_task_slug = ?
        ORDER BY updated_at DESC
        LIMIT 5
        """,
        (int(project["id"]), task_slug),
    ).fetchall()
    guidance_rows = conn.execute(
        """
        SELECT active, position, mode, summary, details, source, created_at
        FROM guidance_entries
        WHERE task_id = ?
        ORDER BY active DESC, position ASC
        """,
        (int(row["id"]),),
    ).fetchall()

    return {
        "generated_at": now_utc(),
        "root": str(root_dir),
        "db_path": str(db_path_for_root(root_dir)),
        "skill_inventory_path": str(skill_inventory_path(root_dir)),
        "project_name": str(project["name"]),
        "task_root": task_root,
        "task_slug": str(row["slug"]),
        "objective": str(row["objective"]),
        "status": str(row["status"]),
        "phase": str(row["phase"]),
        "run_mode": str(row["run_mode"]),
        "run_style": str(row["run_style"]),
        "current": {
            "milestone_id": row["current_milestone_key"] or "",
            "milestone_title": row["current_milestone_title"] or "",
            "slice_id": row["current_slice_key"] or "",
            "slice_title": row["current_slice_title"] or "",
        },
        "queued_milestones": [
            {
                "milestone_id": queue_row["milestone_key"],
                "milestone_title": queue_row["milestone_title"],
                "position": int(queue_row["position"]),
            }
            for queue_row in queue_rows
        ],
        "guidance": guidance_payload_from_rows(guidance_rows),
        "heartbeat": {
            "state": row["heartbeat_state"] or "",
            "last_seen_at": row["heartbeat_last_seen_at"] or "",
            "session_started_at": row["heartbeat_session_started_at"] or "",
            "summary": row["heartbeat_summary"] or "",
            "touched_path": row["heartbeat_touched_path"] or "",
        },
        "last_run": {
            "run_id": row["last_run_id"] or "",
            "stop_reason": row["last_stop_reason"] or "",
            "started_at": row["last_started_at"] or "",
            "ended_at": row["last_ended_at"] or "",
            "summary": row["last_summary"] or "",
            "lineage": {
                "parent_run_id": row["last_parent_run_id"] or "",
                "kind": row["last_lineage_kind"] or "",
                "branch_label": row["last_branch_label"] or "",
            },
        },
        "source_docs": list(config.get("source_docs", {}).get("priority", []))
        if isinstance(config.get("source_docs"), dict)
        else [],
        "recommended_skills": list(config.get("skills", {}).get("default", []))
        if isinstance(config.get("skills"), dict)
        else [],
        "skill_surfaces": {
            "campfire_generated_core": [
                entry
                for entry in skill_inventory.get("skills", [])
                if str(entry.get("scope", "")) == "campfire_generated_core"
            ],
            "repo_local_generated": [
                entry
                for entry in skill_inventory.get("skills", [])
                if str(entry.get("scope", "")) == "repo_local_generated"
            ],
            "task_local_generated": [
                entry
                for entry in skill_inventory.get("skills", [])
                if str(entry.get("scope", "")) == "task_local_generated"
                and str(entry.get("task_slug", "")) == task_slug
            ],
        },
        "recent_validations": [
            {
                "validator_id": validation_row["validator_type"],
                "status": validation_row["status"],
                "summary": validation_row["summary"],
                "timestamp": validation_row["timestamp"],
                "artifact_path": validation_row["artifact_path"],
            }
            for validation_row in validation_rows
        ],
        "recent_artifacts": [
            {
                "milestone_id": artifact_row["milestone_key"],
                "path": artifact_row["path"],
                "kind": artifact_row["kind"],
                "reason": artifact_row["reason"],
                "timestamp": artifact_row["created_at"],
            }
            for artifact_row in artifact_rows
        ],
        "recent_improvement_candidates": [
            improvement_candidate_payload(improvement_row)
            for improvement_row in improvement_rows
        ],
        "task_files": {
            "task_dir": str(root_dir / task_root / task_slug),
            "plan": str(root_dir / task_root / task_slug / "plan.md"),
            "runbook": str(root_dir / task_root / task_slug / "runbook.md"),
            "handoff": str(root_dir / task_root / task_slug / "handoff.md"),
            "progress": str(root_dir / task_root / task_slug / "progress.md"),
            "checkpoints": str(root_dir / task_root / task_slug / "checkpoints.json"),
            "artifacts_manifest": str(root_dir / task_root / task_slug / "artifacts.json"),
        },
    }


def render_registry(conn: sqlite3.Connection, root_dir: Path, output_path: Path | None = None) -> Path:
    project = ensure_project(conn, root_dir)
    if output_path is None:
        output_path = root_dir / ".campfire" / "registry.json"

    task_rows = conn.execute(
        """
        SELECT
          t.slug,
          t.status,
          t.phase,
          t.current_milestone_key,
          t.current_slice_key,
          t.updated_at,
          m.title AS current_milestone_title,
          s.title AS current_slice_title,
          (
            SELECT COUNT(*) FROM queue_entries q WHERE q.task_id = t.id
          ) AS queued_count,
          (
            SELECT COUNT(*) FROM guidance_entries g
            WHERE g.task_id = t.id AND g.active = 1
          ) AS guidance_active_count,
          (
            SELECT COUNT(*) FROM guidance_entries g
            WHERE g.task_id = t.id AND g.active = 0
          ) AS guidance_follow_up_count,
          (
            SELECT g.summary FROM guidance_entries g
            WHERE g.task_id = t.id AND g.active = 1
            ORDER BY g.position ASC
            LIMIT 1
          ) AS guidance_active_summary,
          (
            SELECT g.mode FROM guidance_entries g
            WHERE g.task_id = t.id AND g.active = 1
            ORDER BY g.position ASC
            LIMIT 1
          ) AS guidance_active_mode,
          hb.state AS heartbeat_state,
          hb.last_seen_at AS heartbeat_last_seen_at,
          hb.session_started_at AS heartbeat_session_started_at,
          hb.summary AS heartbeat_summary,
          hb.touched_path AS heartbeat_touched_path,
          sess.run_id AS last_run_id,
          sess.parent_run_id AS last_parent_run_id,
          sess.lineage_kind AS last_lineage_kind,
          sess.branch_label AS last_branch_label,
          sess.stop_reason AS last_stop_reason,
          sess.started_at AS last_started_at,
          sess.ended_at AS last_ended_at,
          sess.summary AS last_summary
        FROM tasks t
        LEFT JOIN milestones m
          ON m.task_id = t.id AND m.milestone_key = t.current_milestone_key
        LEFT JOIN slices s
          ON s.task_id = t.id AND s.slice_key = t.current_slice_key
        LEFT JOIN heartbeats hb
          ON hb.task_id = t.id
        LEFT JOIN sessions sess
          ON sess.id = (
            SELECT id FROM sessions latest
            WHERE latest.task_id = t.id
            ORDER BY latest.started_at DESC
            LIMIT 1
          )
        WHERE t.project_id = ?
        ORDER BY t.updated_at DESC, t.slug ASC
        """,
        (int(project["id"]),),
    ).fetchall()

    tasks: list[dict[str, Any]] = []
    task_root = root_dir / str(project["task_root"])
    for row in task_rows:
        tasks.append(
            {
                "task_slug": row["slug"],
                "task_dir": str(task_root / row["slug"]),
                "status": row["status"],
                "phase": row["phase"],
                "current": {
                    "milestone_id": row["current_milestone_key"] or "",
                    "milestone_title": row["current_milestone_title"] or "",
                    "slice_id": row["current_slice_key"] or "",
                    "slice_title": row["current_slice_title"] or "",
                },
                "queued_count": int(row["queued_count"] or 0),
                "guidance": {
                    "active_count": int(row["guidance_active_count"] or 0),
                    "follow_up_count": int(row["guidance_follow_up_count"] or 0),
                    "active_mode": row["guidance_active_mode"] or "",
                    "active_summary": row["guidance_active_summary"] or "",
                },
                "last_updated": row["updated_at"] or "",
                "last_run": {
                    "run_id": row["last_run_id"] or "",
                    "stop_reason": row["last_stop_reason"] or "",
                    "started_at": row["last_started_at"] or "",
                    "ended_at": row["last_ended_at"] or "",
                    "summary": row["last_summary"] or "",
                    "lineage": {
                        "parent_run_id": row["last_parent_run_id"] or "",
                        "kind": row["last_lineage_kind"] or "",
                        "branch_label": row["last_branch_label"] or "",
                    },
                },
                "heartbeat": {
                    "state": row["heartbeat_state"] or "",
                    "last_seen_at": row["heartbeat_last_seen_at"] or "",
                    "session_started_at": row["heartbeat_session_started_at"] or "",
                    "summary": row["heartbeat_summary"] or "",
                    "touched_path": row["heartbeat_touched_path"] or "",
                },
            }
        )

    payload = {
        "generated_at": now_utc(),
        "root": str(root_dir),
        "db_path": str(db_path_for_root(root_dir)),
        "skill_inventory_path": str(skill_inventory_path(root_dir)),
        "task_count": len(tasks),
        "tasks": tasks,
    }
    dump_json(output_path, payload)
    render_skill_inventory(root_dir, str(project["task_root"]))
    render_improvement_backlog(conn, root_dir)
    dump_json(project_context_path(root_dir), build_project_context(conn, root_dir))
    for task in tasks:
        dump_json(
            task_context_path(root_dir, str(project["task_root"]), str(task["task_slug"])),
            build_task_context(conn, root_dir, str(task["task_slug"])),
        )
    return output_path


def doctor_task(conn: sqlite3.Connection, root_dir: Path, task_slug: str) -> None:
    project = ensure_project(conn, root_dir)
    task_root = root_dir / str(project["task_root"])
    task_dir = task_root / task_slug
    checkpoint = load_json(task_dir / "checkpoints.json")
    heartbeat = load_json(task_dir / "heartbeat.json")
    row = conn.execute(
        """
        SELECT
          t.id,
          t.status,
          t.phase,
          t.current_milestone_key,
          t.current_slice_key,
          (
            SELECT COUNT(*) FROM guidance_entries g
            WHERE g.task_id = t.id AND g.active = 1
          ) AS guidance_active_count,
          (
            SELECT COUNT(*) FROM guidance_entries g
            WHERE g.task_id = t.id AND g.active = 0
          ) AS guidance_follow_up_count,
          (
            SELECT g.summary FROM guidance_entries g
            WHERE g.task_id = t.id AND g.active = 1
            ORDER BY g.position ASC
            LIMIT 1
          ) AS guidance_active_summary,
          (
            SELECT g.mode FROM guidance_entries g
            WHERE g.task_id = t.id AND g.active = 1
            ORDER BY g.position ASC
            LIMIT 1
          ) AS guidance_active_mode,
          (
            SELECT s.run_id FROM sessions s
            WHERE s.task_id = t.id
            ORDER BY s.started_at DESC
            LIMIT 1
          ) AS last_run_id,
          (
            SELECT s.parent_run_id FROM sessions s
            WHERE s.task_id = t.id
            ORDER BY s.started_at DESC
            LIMIT 1
          ) AS last_parent_run_id,
          (
            SELECT s.lineage_kind FROM sessions s
            WHERE s.task_id = t.id
            ORDER BY s.started_at DESC
            LIMIT 1
          ) AS last_lineage_kind,
          (
            SELECT s.branch_label FROM sessions s
            WHERE s.task_id = t.id
            ORDER BY s.started_at DESC
            LIMIT 1
          ) AS last_branch_label,
          hb.state AS heartbeat_state,
          hb.last_seen_at AS heartbeat_last_seen_at
        FROM tasks t
        LEFT JOIN heartbeats hb ON hb.task_id = t.id
        WHERE t.project_id = ? AND t.slug = ?
        """,
        (int(project["id"]), task_slug),
    ).fetchone()
    if row is None:
        raise SystemExit(f"Doctor failed: task not present in DB ({task_slug})")

    failures: list[str] = []
    checkpoint_status = str(checkpoint.get("status", "")).strip()
    if checkpoint_status != row["status"]:
        failures.append(
            f"status mismatch: checkpoints={checkpoint_status!r} db={row['status']!r}"
        )

    current = checkpoint.get("current", {})
    if not isinstance(current, dict):
        current = {}
    guidance = normalize_guidance(checkpoint.get("guidance", {}))
    checkpoint_milestone = str(current.get("milestone_id", "")).strip()
    checkpoint_slice = str(current.get("slice_id", "")).strip()
    if checkpoint_milestone != (row["current_milestone_key"] or ""):
        failures.append(
            "current milestone mismatch between checkpoints and DB"
        )
    if checkpoint_slice != (row["current_slice_key"] or ""):
        failures.append("current slice mismatch between checkpoints and DB")

    if checkpoint_status == "in_progress" and not checkpoint_slice:
        failures.append("in_progress task is missing an active slice")

    active_guidance = guidance.get("active")
    checkpoint_active_summary = ""
    checkpoint_active_mode = ""
    if isinstance(active_guidance, dict):
        checkpoint_active_summary = str(active_guidance.get("summary", "")).strip()
        checkpoint_active_mode = str(active_guidance.get("mode", "")).strip()
    checkpoint_follow_up_count = len(guidance.get("follow_ups", []))
    if checkpoint_active_summary != (row["guidance_active_summary"] or ""):
        failures.append("active guidance summary mismatch between checkpoints and DB")
    if checkpoint_active_mode != (row["guidance_active_mode"] or ""):
        failures.append("active guidance mode mismatch between checkpoints and DB")
    if int(bool(checkpoint_active_summary)) != int(row["guidance_active_count"] or 0):
        failures.append("active guidance count mismatch between checkpoints and DB")
    if checkpoint_follow_up_count != int(row["guidance_follow_up_count"] or 0):
        failures.append("follow-up guidance count mismatch between checkpoints and DB")

    last_run = checkpoint.get("last_run", {})
    if not isinstance(last_run, dict):
        last_run = {}
    checkpoint_run_id = str(last_run.get("run_id", "")).strip() or str(last_run.get("started_at", "")).strip()
    checkpoint_lineage = normalize_lineage(last_run.get("lineage", {}))
    if checkpoint_run_id != (row["last_run_id"] or ""):
        failures.append("last_run run_id mismatch between checkpoints and DB")
    if checkpoint_lineage["parent_run_id"] != (row["last_parent_run_id"] or ""):
        failures.append("last_run parent_run_id mismatch between checkpoints and DB")
    if checkpoint_lineage["kind"] != (row["last_lineage_kind"] or ""):
        failures.append("last_run lineage kind mismatch between checkpoints and DB")
    if checkpoint_lineage["branch_label"] != (row["last_branch_label"] or ""):
        failures.append("last_run branch label mismatch between checkpoints and DB")

    if heartbeat:
        heartbeat_state = str(heartbeat.get("state", "")).strip()
        if heartbeat_state != (row["heartbeat_state"] or ""):
            failures.append(
                f"heartbeat mismatch: file={heartbeat_state!r} db={row['heartbeat_state']!r}"
            )

    registry_path = root_dir / ".campfire" / "registry.json"
    if not registry_path.exists():
        failures.append("registry.json is missing")
    task_context_file = task_context_path(root_dir, str(project["task_root"]), task_slug)
    if not task_context_file.exists():
        failures.append("task_context.json is missing")
    project_context_file = project_context_path(root_dir)
    if not project_context_file.exists():
        failures.append("project_context.json is missing")
    improvement_backlog_file = improvement_backlog_path(root_dir)
    if not improvement_backlog_file.exists():
        failures.append("improvement_backlog.json is missing")
    skill_inventory_file = skill_inventory_path(root_dir)
    if not skill_inventory_file.exists():
        failures.append("skill_inventory.json is missing")

    if task_context_file.exists():
        task_context = load_json(task_context_file)
        if str(task_context.get("status", "")).strip() != (row["status"] or ""):
            failures.append("task_context status mismatch")
        if str(task_context.get("skill_inventory_path", "")).strip() != str(skill_inventory_file):
            failures.append("task_context skill_inventory_path mismatch")
        context_current = task_context.get("current", {})
        if not isinstance(context_current, dict):
            context_current = {}
        if str(context_current.get("milestone_id", "")).strip() != (row["current_milestone_key"] or ""):
            failures.append("task_context current milestone mismatch")
        if str(context_current.get("slice_id", "")).strip() != (row["current_slice_key"] or ""):
            failures.append("task_context current slice mismatch")
        context_last_run = task_context.get("last_run", {})
        if not isinstance(context_last_run, dict):
            context_last_run = {}
        context_lineage = context_last_run.get("lineage", {})
        if not isinstance(context_lineage, dict):
            context_lineage = {}
        if str(context_last_run.get("run_id", "")).strip() != (row["last_run_id"] or ""):
            failures.append("task_context last_run run_id mismatch")
        if str(context_lineage.get("parent_run_id", "")).strip() != (row["last_parent_run_id"] or ""):
            failures.append("task_context lineage parent_run_id mismatch")
        if str(context_lineage.get("kind", "")).strip() != (row["last_lineage_kind"] or ""):
            failures.append("task_context lineage kind mismatch")
        if str(context_lineage.get("branch_label", "")).strip() != (row["last_branch_label"] or ""):
            failures.append("task_context lineage branch label mismatch")
        context_guidance = task_context.get("guidance", {})
        if not isinstance(context_guidance, dict):
            context_guidance = {}
        context_active = context_guidance.get("active")
        if context_active is None:
            context_active = {}
        if not isinstance(context_active, dict):
            context_active = {}
        context_follow_ups = context_guidance.get("follow_ups", [])
        if not isinstance(context_follow_ups, list):
            context_follow_ups = []
        if str(context_active.get("summary", "")).strip() != (row["guidance_active_summary"] or ""):
            failures.append("task_context active guidance summary mismatch")
        if str(context_active.get("mode", "")).strip() != (row["guidance_active_mode"] or ""):
            failures.append("task_context active guidance mode mismatch")
        if len(context_follow_ups) != int(row["guidance_follow_up_count"] or 0):
            failures.append("task_context follow-up guidance count mismatch")

    if project_context_file.exists():
        project_context = load_json(project_context_file)
        if str(project_context.get("db_path", "")).strip() != str(db_path_for_root(root_dir)):
            failures.append("project_context db_path mismatch")
        if str(project_context.get("improvement_backlog_path", "")).strip() != str(improvement_backlog_file):
            failures.append("project_context improvement_backlog_path mismatch")
        if str(project_context.get("skill_inventory_path", "")).strip() != str(skill_inventory_file):
            failures.append("project_context skill_inventory_path mismatch")

    if registry_path.exists():
        registry = load_json(registry_path)
        registry_tasks = registry.get("tasks", [])
        if not isinstance(registry_tasks, list):
            registry_tasks = []
        registry_task = next(
            (
                item for item in registry_tasks
                if isinstance(item, dict) and str(item.get("task_slug", "")).strip() == task_slug
            ),
            None,
        )
        if registry_task is None:
            failures.append("registry task entry missing")
        else:
            registry_guidance = registry_task.get("guidance", {})
            if not isinstance(registry_guidance, dict):
                registry_guidance = {}
            if int(registry_guidance.get("active_count", 0) or 0) != int(row["guidance_active_count"] or 0):
                failures.append("registry active guidance count mismatch")
            if int(registry_guidance.get("follow_up_count", 0) or 0) != int(row["guidance_follow_up_count"] or 0):
                failures.append("registry follow-up guidance count mismatch")
            if str(registry_guidance.get("active_summary", "")).strip() != (row["guidance_active_summary"] or ""):
                failures.append("registry active guidance summary mismatch")
            if str(registry_guidance.get("active_mode", "")).strip() != (row["guidance_active_mode"] or ""):
                failures.append("registry active guidance mode mismatch")
            registry_last_run = registry_task.get("last_run", {})
            if not isinstance(registry_last_run, dict):
                registry_last_run = {}
            registry_lineage = registry_last_run.get("lineage", {})
            if not isinstance(registry_lineage, dict):
                registry_lineage = {}
            if str(registry_last_run.get("run_id", "")).strip() != (row["last_run_id"] or ""):
                failures.append("registry last_run run_id mismatch")
            if str(registry_lineage.get("parent_run_id", "")).strip() != (row["last_parent_run_id"] or ""):
                failures.append("registry lineage parent_run_id mismatch")
            if str(registry_lineage.get("kind", "")).strip() != (row["last_lineage_kind"] or ""):
                failures.append("registry lineage kind mismatch")
            if str(registry_lineage.get("branch_label", "")).strip() != (row["last_branch_label"] or ""):
                failures.append("registry lineage branch label mismatch")

    if failures:
        message = "\n".join(f"- {item}" for item in failures)
        raise SystemExit(f"Doctor failed for {task_slug}:\n{message}")

    print(f"Doctor passed: {task_slug}")
    print(f"  db_path: {db_path_for_root(root_dir)}")
    print(f"  status: {row['status']}")
    print(f"  heartbeat: {row['heartbeat_state'] or '(none)'}")


def command_sync_task(args: argparse.Namespace) -> int:
    root_dir = Path(args.root).resolve()
    conn = connect_db(root_dir)
    try:
        payload = sync_task(conn, root_dir, args.task_slug)
    finally:
        conn.close()
    print(json.dumps(payload, indent=2))
    return 0


def command_sync_all(args: argparse.Namespace) -> int:
    root_dir = Path(args.root).resolve()
    conn = connect_db(root_dir)
    try:
        payloads = sync_all(conn, root_dir)
    finally:
        conn.close()
    print(json.dumps({"task_count": len(payloads), "tasks": payloads}, indent=2))
    return 0


def command_render_registry(args: argparse.Namespace) -> int:
    root_dir = Path(args.root).resolve()
    conn = connect_db(root_dir)
    try:
        output_path = render_registry(conn, root_dir)
    finally:
        conn.close()
    print(f"Registry rendered: {output_path}")
    return 0


def command_doctor_task(args: argparse.Namespace) -> int:
    root_dir = Path(args.root).resolve()
    conn = connect_db(root_dir)
    try:
        sync_task(conn, root_dir, args.task_slug)
        render_registry(conn, root_dir)
        doctor_task(conn, root_dir, args.task_slug)
    finally:
        conn.close()
    return 0


def command_record_improvement_candidate(args: argparse.Namespace) -> int:
    root_dir = Path(args.root).resolve()
    conn = connect_db(root_dir)
    try:
        payload = upsert_improvement_candidate(
            conn,
            root_dir,
            task_slug=args.task_slug or "",
            candidate_id=args.candidate_id or "",
            source_type=args.source_type,
            source_milestone_key=args.source_milestone_id or "",
            source_run_id=args.source_run_id or "",
            title=args.title,
            category=args.category,
            scope=args.scope,
            promotion_state=args.promotion_state,
            problem=args.problem,
            why_not_script=args.why_not_script or "",
            evidence=list(args.evidence or []),
            trigger_pattern=list(args.trigger_pattern or []),
            proposed_skill_name=args.proposed_skill_name or "",
            proposed_skill_purpose=args.proposed_skill_purpose or "",
            confidence=args.confidence or "",
            next_action=args.next_action,
            promoted_task_slug=args.promoted_task_slug or "",
            output_path=args.output_path or "",
        )
        render_improvement_backlog(conn, root_dir)
        dump_json(project_context_path(root_dir), build_project_context(conn, root_dir))
        if args.task_slug:
            dump_json(
                task_context_path(root_dir, str(ensure_project(conn, root_dir)["task_root"]), args.task_slug),
                build_task_context(conn, root_dir, args.task_slug),
            )
    finally:
        conn.close()
    print(json.dumps(payload, indent=2))
    return 0


def command_show_improvement_candidate(args: argparse.Namespace) -> int:
    root_dir = Path(args.root).resolve()
    conn = connect_db(root_dir)
    try:
        project = ensure_project(conn, root_dir)
        row = conn.execute(
            """
            SELECT *
            FROM improvement_candidates
            WHERE project_id = ? AND candidate_id = ?
            """,
            (int(project["id"]), args.candidate_id),
        ).fetchone()
        if row is None:
            raise SystemExit(f"Improvement candidate not found: {args.candidate_id}")
        payload = improvement_candidate_payload(row)
    finally:
        conn.close()
    print(json.dumps(payload, indent=2))
    return 0


def command_render_improvement_backlog(args: argparse.Namespace) -> int:
    root_dir = Path(args.root).resolve()
    conn = connect_db(root_dir)
    try:
        output_path = render_improvement_backlog(conn, root_dir)
        dump_json(project_context_path(root_dir), build_project_context(conn, root_dir))
    finally:
        conn.close()
    print(f"Improvement backlog rendered: {output_path}")
    return 0


def command_promote_improvement_candidate(args: argparse.Namespace) -> int:
    root_dir = Path(args.root).resolve()
    conn = connect_db(root_dir)
    try:
        payload = update_improvement_candidate_promotion(
            conn,
            root_dir,
            args.candidate_id,
            args.promotion_state,
            args.promoted_task_slug,
        )
        render_improvement_backlog(conn, root_dir)
        dump_json(project_context_path(root_dir), build_project_context(conn, root_dir))
        if payload["source"]["task_slug"]:
            project = ensure_project(conn, root_dir)
            dump_json(
                task_context_path(
                    root_dir,
                    str(project["task_root"]),
                    str(payload["source"]["task_slug"]),
                ),
                build_task_context(conn, root_dir, str(payload["source"]["task_slug"])),
            )
    finally:
        conn.close()
    print(json.dumps(payload, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Campfire SQLite control plane helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    for name, handler in {
        "sync-task": command_sync_task,
        "sync-all": command_sync_all,
        "render-registry": command_render_registry,
        "doctor-task": command_doctor_task,
        "record-improvement-candidate": command_record_improvement_candidate,
        "show-improvement-candidate": command_show_improvement_candidate,
        "render-improvement-backlog": command_render_improvement_backlog,
        "promote-improvement-candidate": command_promote_improvement_candidate,
    }.items():
        subparser = subparsers.add_parser(name)
        subparser.add_argument("--root", required=True)
        if name in {"sync-task", "doctor-task"}:
            subparser.add_argument("task_slug")
        if name == "record-improvement-candidate":
            subparser.add_argument("--task-slug")
            subparser.add_argument("--candidate-id")
            subparser.add_argument("--source-type", default="task_run")
            subparser.add_argument("--source-milestone-id")
            subparser.add_argument("--source-run-id")
            subparser.add_argument("--category", required=True)
            subparser.add_argument("--scope", required=True)
            subparser.add_argument("--promotion-state", default="proposed")
            subparser.add_argument("--title", required=True)
            subparser.add_argument("--problem", required=True)
            subparser.add_argument("--why-not-script")
            subparser.add_argument("--evidence", action="append", default=[])
            subparser.add_argument("--trigger-pattern", action="append", default=[])
            subparser.add_argument("--proposed-skill-name")
            subparser.add_argument("--proposed-skill-purpose")
            subparser.add_argument("--confidence")
            subparser.add_argument("--next-action", required=True)
            subparser.add_argument("--promoted-task-slug")
            subparser.add_argument("--output-path")
        if name == "show-improvement-candidate":
            subparser.add_argument("candidate_id")
        if name == "promote-improvement-candidate":
            subparser.add_argument("--promotion-state", required=True)
            subparser.add_argument("--promoted-task-slug", required=True)
            subparser.add_argument("candidate_id")
        subparser.set_defaults(func=handler)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
