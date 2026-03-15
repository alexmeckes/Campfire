import { startTransition, useEffect, useMemo, useState } from "react";
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
  if (task.status === "blocked" || task.status === "waiting_on_decision") {
    return "Blocked";
  }
  if (task.status === "validated") {
    return "Done";
  }
  if (task.status === "in_progress") {
    return "Now";
  }
  return "Next";
}

function toneForTask(task: TaskBoardItem) {
  if (task.status === "blocked") {
    return "blocked";
  }
  if (task.status === "waiting_on_decision") {
    return "waiting";
  }
  if (task.status === "validated") {
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

export default function App() {
  const [payload, setPayload] = useState<{
    repos: { root: string; name: string }[];
    tasks: TaskBoardItem[];
  } | null>(null);
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(null);
  const [activeRepo, setActiveRepo] = useState("all");
  const [error, setError] = useState<string | null>(null);
  const [liveState, setLiveState] = useState("connecting");
  const [alwaysOnTop, setAlwaysOnTop] = useState(false);

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
    } catch (nextError) {
      setError(nextError instanceof Error ? nextError.message : "Unable to load board.");
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
    eventSource.addEventListener("tasks-changed", () => {
      setLiveState("syncing");
      void loadBoard().finally(() => setLiveState("live"));
    });
    eventSource.onerror = () => {
      setLiveState("reconnecting");
    };

    return () => {
      eventSource.close();
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
                  className={`card ${selectedTask?.id === task.id ? "card-selected" : ""}`}
                  onClick={() => setSelectedTaskId(task.id)}
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
            </div>
            <div className="tray-meta">
              <span>{selectedTask.queuedMilestones.length} queued</span>
              <span>{selectedTask.validation?.type || "no proof"}</span>
              <span>{selectedTask.lastRun.stopReason || "running"}</span>
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
