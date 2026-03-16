import { startTransition, useEffect, useMemo, useRef, useState } from "react";
import type { TaskBoardItem } from "../shared/types";

type Lane = "Now" | "Next" | "Blocked" | "Done";

const LANE_ORDER: Lane[] = ["Now", "Next", "Blocked", "Done"];

function copyText(value: string | null) {
  if (!value) {
    return;
  }
  void navigator.clipboard.writeText(value);
}

function laneForTask(task: TaskBoardItem): Lane {
  if (task.column === "Blocked" || task.column === "Waiting") {
    return "Blocked";
  }
  if (task.column === "Validated") {
    return "Done";
  }
  if (task.column === "Active") {
    return "Now";
  }
  return "Next";
}

function toneForTask(task: TaskBoardItem) {
  if (task.column === "Blocked" && task.status === "blocked") {
    return "blocked";
  }
  if (task.column === "Blocked" && task.status === "waiting_on_decision") {
    return "waiting";
  }
  if (task.column === "Validated") {
    return "done";
  }
  if (task.health === "Needs Reframe") {
    return "warning";
  }
  return "healthy";
}

function milestoneId(task: TaskBoardItem) {
  return task.currentMilestone?.id || laneForTask(task);
}

function latestProgressLine(markdown: string) {
  const lines = markdown
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);

  for (let index = lines.length - 1; index >= 0; index -= 1) {
    const line = lines[index];
    if (line.startsWith("- ")) {
      return line.slice(2).trim();
    }
    if (!line.startsWith("#")) {
      return line;
    }
  }

  return null;
}

function relativeTimeLabel(value: string | null, nowMs: number, fallback: string) {
  if (!value) {
    return fallback;
  }

  const timestamp = new Date(value).getTime();
  if (Number.isNaN(timestamp)) {
    return fallback;
  }

  const deltaMs = Math.max(0, nowMs - timestamp);
  const deltaSeconds = Math.floor(deltaMs / 1000);
  if (deltaSeconds < 10) {
    return "just now";
  }
  if (deltaSeconds < 60) {
    return `${deltaSeconds}s ago`;
  }

  const deltaMinutes = Math.floor(deltaSeconds / 60);
  if (deltaMinutes < 60) {
    return `${deltaMinutes}m ago`;
  }

  const deltaHours = Math.floor(deltaMinutes / 60);
  if (deltaHours < 24) {
    return `${deltaHours}h ago`;
  }

  const deltaDays = Math.floor(deltaHours / 24);
  return `${deltaDays}d ago`;
}

function formatLiveLabel(liveState: string, lastSyncAt: string | null, nowMs: number) {
  const labels: Record<string, string> = {
    connecting: "Connecting",
    live: "Live",
    syncing: "Syncing",
    reconnecting: "Reconnecting",
  };

  const base = labels[liveState] || "Live";
  if (!lastSyncAt) {
    return base;
  }

  return `${base} ${relativeTimeLabel(lastSyncAt, nowMs, "recently")}`;
}

function formatHeartbeatLabel(value: string | null, nowMs: number) {
  if (!value) {
    return "no heartbeat";
  }
  return `heartbeat ${relativeTimeLabel(value, nowMs, "recently")}`;
}

export default function App() {
  const [payload, setPayload] = useState<{
    repos: { root: string; name: string }[];
    tasks: TaskBoardItem[];
  } | null>(null);
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(null);
  const [activeRepo, setActiveRepo] = useState("all");
  const [error, setError] = useState<string | null>(null);
  const [liveState, setLiveState] = useState("connecting");
  const [lastSyncAt, setLastSyncAt] = useState<string | null>(null);
  const [nowMs, setNowMs] = useState(() => Date.now());
  const [alwaysOnTop, setAlwaysOnTop] = useState(false);
  const [recentTaskIds, setRecentTaskIds] = useState<string[]>([]);
  const tasksRef = useRef<TaskBoardItem[]>([]);
  const clearTimersRef = useRef<Record<string, number>>({});

  async function loadBoard() {
    try {
      const response = await fetch("/api/board");
      if (!response.ok) {
        throw new Error(`Failed to load board: ${response.status}`);
      }

      const nextPayload = (await response.json()) as {
        repos: { root: string; name: string }[];
        tasks: TaskBoardItem[];
      };

      setError(null);
      startTransition(() => {
        setPayload(nextPayload);
        setSelectedTaskId((current) => {
          if (current && nextPayload.tasks.some((task) => task.id === current)) {
            return current;
          }
          return nextPayload.tasks[0]?.id ?? null;
        });
      });
      setLastSyncAt(nextPayload.generatedAt || new Date().toISOString());
      tasksRef.current = nextPayload.tasks;
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Unable to load board.");
    }
  }

  function markRecentTaskIds(taskIds: string[]) {
    if (taskIds.length === 0) {
      return;
    }

    setRecentTaskIds((current) => [...new Set([...current, ...taskIds])]);

    for (const taskId of taskIds) {
      const existingTimer = clearTimersRef.current[taskId];
      if (existingTimer) {
        window.clearTimeout(existingTimer);
      }

      clearTimersRef.current[taskId] = window.setTimeout(() => {
        setRecentTaskIds((current) => current.filter((entry) => entry !== taskId));
        delete clearTimersRef.current[taskId];
      }, 3200);
    }
  }

  useEffect(() => {
    void loadBoard();

    void window.campfireBoardDesktop?.getAlwaysOnTop?.().then((nextValue) => {
      setAlwaysOnTop(nextValue);
    });

    const eventSource = new EventSource("/api/events");
    eventSource.addEventListener("ready", () => {
      setLiveState("live");
    });
    eventSource.addEventListener("tasks-changed", (event) => {
      setLiveState("syncing");

      let changedPath = "";
      if ("data" in event && typeof event.data === "string") {
        try {
          const payload = JSON.parse(event.data) as { changedPath?: string };
          changedPath = payload.changedPath || "";
        } catch {
          changedPath = "";
        }
      }

      const changedTasks = changedPath
        ? tasksRef.current
            .filter((task) => {
              if (changedPath.startsWith(task.files.taskDir)) {
                return true;
              }

              return changedPath === `${task.repoRoot}/.campfire/registry.json`;
            })
            .map((task) => task.id)
        : [];
      markRecentTaskIds(changedTasks);

      void loadBoard().finally(() => {
        setLiveState("live");
      });
    });
    eventSource.onerror = () => {
      setLiveState("reconnecting");
    };

    return () => {
      eventSource.close();

      for (const timer of Object.values(clearTimersRef.current)) {
        window.clearTimeout(timer);
      }
      clearTimersRef.current = {};
    };
  }, []);

  useEffect(() => {
    const interval = window.setInterval(() => {
      setNowMs(Date.now());
    }, 10000);

    return () => {
      window.clearInterval(interval);
    };
  }, []);

  const filteredTasks = useMemo(() => {
    const tasks = payload?.tasks ?? [];
    return tasks.filter((task) =>
      activeRepo === "all" ? true : task.repoRoot === activeRepo
    );
  }, [payload, activeRepo]);

  const selectedTask =
    filteredTasks.find((task) => task.id === selectedTaskId) ||
    filteredTasks[0] ||
    null;

  const grouped = useMemo(
    () =>
      LANE_ORDER.map((lane) => ({
        lane,
        tasks: filteredTasks.filter((task) => laneForTask(task) === lane),
      })),
    [filteredTasks]
  );

  const showRepoPicker = (payload?.repos.length ?? 0) > 1;
  const liveLabel = formatLiveLabel(liveState, lastSyncAt, nowMs);

  async function toggleAlwaysOnTop() {
    const nextValue = await window.campfireBoardDesktop?.setAlwaysOnTop?.(!alwaysOnTop);
    if (typeof nextValue === "boolean") {
      setAlwaysOnTop(nextValue);
    }
  }

  return (
    <div className="widget-shell">
      <header className="topbar">
        <div className="brand-row">
          <span className="brand-mark">Campfire</span>
          <span className={`live-dot live-dot-${liveState}`} />
          <span className="live-label">{liveLabel}</span>
        </div>

        <div className="topbar-actions">
          {window.campfireBoardDesktop?.mode === "electron" ? (
            <button
              className={`control subtle-button pin-toggle ${alwaysOnTop ? "pin-toggle-active" : ""}`}
              onClick={() => void toggleAlwaysOnTop()}
              aria-pressed={alwaysOnTop}
              title={alwaysOnTop ? "Unpin window" : "Keep window on top"}
            >
              Pin
            </button>
          ) : null}
          {showRepoPicker ? (
            <select
              className="control compact-select"
              value={activeRepo}
              onChange={(event) => setActiveRepo(event.target.value)}
            >
              <option value="all">All repos</option>
              {(payload?.repos ?? []).map((repo) => (
                <option key={repo.root} value={repo.root}>
                  {repo.name}
                </option>
              ))}
            </select>
          ) : null}
          <button className="control subtle-button" onClick={() => void loadBoard()}>
            ↻
          </button>
        </div>
      </header>

      {error ? <div className="banner banner-error">{error}</div> : null}

      <main className="kanban">
        {grouped.map(({ lane, tasks }) => (
          <section key={lane} className="lane">
            <header className="lane-header">
              <span>{lane}</span>
              <strong>{tasks.length}</strong>
            </header>

            <div className="lane-body">
              {tasks.map((task) => (
                <button
                  key={task.id}
                  className={`card ${selectedTask?.id === task.id ? "card-selected" : ""} ${recentTaskIds.includes(task.id) ? "card-activity" : ""}`}
                  onClick={() => setSelectedTaskId(task.id)}
                  data-task-id={task.id}
                  data-task-slug={task.taskSlug}
                >
                  <div className="card-top">
                    <span className={`status-dot status-dot-${toneForTask(task)}`} />
                    <span className="card-milestone">{milestoneId(task)}</span>
                  </div>
                  <strong>{task.taskSlug}</strong>
                </button>
              ))}

              {tasks.length === 0 ? <div className="empty-card" /> : null}
            </div>
          </section>
        ))}
      </main>

      {selectedTask ? (
        <footer className="detail-tray">
          <div className="tray-main">
            <div>
              <strong>{selectedTask.taskSlug}</strong>
              <span>{selectedTask.currentMilestone?.id || laneForTask(selectedTask)}</span>
              <p className="tray-progress">
                {latestProgressLine(selectedTask.progressMarkdown) ||
                  selectedTask.lastRun.nextStep ||
                  selectedTask.handoff.nextSlice ||
                  "No recent progress note."}
              </p>
            </div>
            <div className="tray-meta">
              <span>{selectedTask.queuedMilestones.length} queued</span>
              <span>{selectedTask.validation?.type || "no proof"}</span>
              <span>{selectedTask.lastRun.stopReason || "running"}</span>
              <span>{formatHeartbeatLabel(selectedTask.heartbeat?.lastSeenAt || null, nowMs)}</span>
            </div>
          </div>

          <div className="tray-actions">
            <button
              className="control subtle-button"
              onClick={() => copyText(selectedTask.handoff.resumePrompt)}
            >
              Copy prompt
            </button>
            <a
              className="tray-link"
              href={`/api/raw?path=${encodeURIComponent(selectedTask.files.handoff)}`}
              target="_blank"
              rel="noreferrer"
            >
              Handoff
            </a>
          </div>
        </footer>
      ) : null}
    </div>
  );
}
