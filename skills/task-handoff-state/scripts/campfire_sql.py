#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
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
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


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

        CREATE TABLE IF NOT EXISTS sessions (
          id INTEGER PRIMARY KEY,
          task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
          started_at TEXT NOT NULL,
          ended_at TEXT,
          stop_reason TEXT NOT NULL DEFAULT '',
          summary TEXT NOT NULL DEFAULT '',
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

        PRAGMA user_version = 1;
        """
    )
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
    session_started_at = str(last_run.get("started_at", "")).strip() or str(heartbeat.get("session_started_at", "")).strip()
    session_id: int | None = None
    if session_started_at:
        conn.execute(
            """
            INSERT INTO sessions(task_id, started_at, ended_at, stop_reason, summary)
            VALUES(?, ?, ?, ?, ?)
            ON CONFLICT(task_id, started_at) DO UPDATE SET
              ended_at = excluded.ended_at,
              stop_reason = excluded.stop_reason,
              summary = excluded.summary
            """,
            (
                task_id,
                session_started_at,
                str(last_run.get("ended_at", "")).strip() or None,
                str(last_run.get("stop_reason", "")).strip(),
                str(last_run.get("summary", "")).strip(),
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


def build_project_context(conn: sqlite3.Connection, root_dir: Path) -> dict[str, Any]:
    project = ensure_project(conn, root_dir)
    config = load_config(root_dir)
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
    validators = config.get("validators", [])
    return {
        "generated_at": now_utc(),
        "root": str(root_dir),
        "project_name": str(project["name"]),
        "task_root": str(project["task_root"]),
        "db_path": str(db_path_for_root(root_dir)),
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
        "task_defaults": config.get("task_defaults", {})
        if isinstance(config.get("task_defaults"), dict)
        else {},
    }


def build_task_context(conn: sqlite3.Connection, root_dir: Path, task_slug: str) -> dict[str, Any]:
    project = ensure_project(conn, root_dir)
    config = load_config(root_dir)
    task_root = str(project["task_root"])
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

    return {
        "generated_at": now_utc(),
        "root": str(root_dir),
        "db_path": str(db_path_for_root(root_dir)),
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
        "heartbeat": {
            "state": row["heartbeat_state"] or "",
            "last_seen_at": row["heartbeat_last_seen_at"] or "",
            "session_started_at": row["heartbeat_session_started_at"] or "",
            "summary": row["heartbeat_summary"] or "",
            "touched_path": row["heartbeat_touched_path"] or "",
        },
        "last_run": {
            "stop_reason": row["last_stop_reason"] or "",
            "started_at": row["last_started_at"] or "",
            "ended_at": row["last_ended_at"] or "",
            "summary": row["last_summary"] or "",
        },
        "source_docs": list(config.get("source_docs", {}).get("priority", []))
        if isinstance(config.get("source_docs"), dict)
        else [],
        "recommended_skills": list(config.get("skills", {}).get("default", []))
        if isinstance(config.get("skills"), dict)
        else [],
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
          hb.state AS heartbeat_state,
          hb.last_seen_at AS heartbeat_last_seen_at,
          hb.session_started_at AS heartbeat_session_started_at,
          hb.summary AS heartbeat_summary,
          hb.touched_path AS heartbeat_touched_path,
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
                "last_updated": row["updated_at"] or "",
                "last_run": {
                    "stop_reason": row["last_stop_reason"] or "",
                    "started_at": row["last_started_at"] or "",
                    "ended_at": row["last_ended_at"] or "",
                    "summary": row["last_summary"] or "",
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
        "task_count": len(tasks),
        "tasks": tasks,
    }
    dump_json(output_path, payload)
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

    if task_context_file.exists():
        task_context = load_json(task_context_file)
        if str(task_context.get("status", "")).strip() != (row["status"] or ""):
            failures.append("task_context status mismatch")
        context_current = task_context.get("current", {})
        if not isinstance(context_current, dict):
            context_current = {}
        if str(context_current.get("milestone_id", "")).strip() != (row["current_milestone_key"] or ""):
            failures.append("task_context current milestone mismatch")
        if str(context_current.get("slice_id", "")).strip() != (row["current_slice_key"] or ""):
            failures.append("task_context current slice mismatch")

    if project_context_file.exists():
        project_context = load_json(project_context_file)
        if str(project_context.get("db_path", "")).strip() != str(db_path_for_root(root_dir)):
            failures.append("project_context db_path mismatch")

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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Campfire SQLite control plane helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    for name, handler in {
        "sync-task": command_sync_task,
        "sync-all": command_sync_all,
        "render-registry": command_render_registry,
        "doctor-task": command_doctor_task,
    }.items():
        subparser = subparsers.add_parser(name)
        subparser.add_argument("--root", required=True)
        if name in {"sync-task", "doctor-task"}:
            subparser.add_argument("task_slug")
        subparser.set_defaults(func=handler)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
