import { promises as fs } from "node:fs";
import path from "node:path";
import type {
  ArtifactRecord,
  BoardPayload,
  BoardColumn,
  MilestoneRef,
  RepoInfo,
  TaskBoardItem,
  TaskHealth,
  TaskStatus,
} from "../shared/types.js";

type CheckpointsShape = {
  task_slug?: string;
  objective?: string;
  status?: TaskStatus;
  current?: {
    milestone_id?: string;
    milestone_title?: string;
    slice_title?: string;
  };
  execution?: {
    mode?: "single_milestone" | "rolling";
    run_style?: "bounded" | "until_stopped";
    planning_slice_minutes?: number;
    runtime_budget_minutes?: number;
    target_queue_depth?: number;
    queued_milestones?: Array<{
      milestone_id?: string;
      milestone_title?: string;
    }>;
  };
  blocker?: {
    status?: string;
    type?: string;
    summary?: string;
    attempts?: number;
    next_action?: string;
  };
  validation?: Array<{
    type?: string;
    summary?: string;
    timestamp?: string;
  }>;
  last_run?: {
    stop_reason?: string;
    events?: string[];
    summary?: string;
    started_at?: string;
    ended_at?: string;
    next_step?: string;
  };
  last_updated?: string;
};

type ArtifactsManifestShape = {
  artifacts?: Array<{
    path?: string;
    type?: string;
    reason?: string;
    milestone_id?: string;
  }>;
};

const REQUIRED_FILES = [
  "checkpoints.json",
  "handoff.md",
  "progress.md",
  "plan.md",
  "runbook.md",
  "artifacts.json",
];

async function readText(filePath: string): Promise<string> {
  return fs.readFile(filePath, "utf8");
}

async function readJson<T>(filePath: string): Promise<T> {
  const raw = await readText(filePath);
  return JSON.parse(raw) as T;
}

async function exists(filePath: string): Promise<boolean> {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

function findSection(markdown: string, heading: string): string | null {
  const marker = `## ${heading}`;
  const start = markdown.indexOf(marker);
  if (start === -1) {
    return null;
  }

  const afterMarker = markdown.slice(start + marker.length).trimStart();
  const nextHeadingIndex = afterMarker.search(/\n##\s+/);
  const section =
    nextHeadingIndex === -1
      ? afterMarker
      : afterMarker.slice(0, nextHeadingIndex).trimEnd();
  return section.trim() || null;
}

function extractBulletValue(markdown: string, label: string): string | null {
  const pattern = new RegExp(`-\\s+${label}:\\s+(.+)`);
  const match = markdown.match(pattern);
  return match?.[1]?.trim() ?? null;
}

function mapColumn(status: TaskStatus): BoardColumn {
  switch (status) {
    case "in_progress":
      return "Active";
    case "blocked":
      return "Blocked";
    case "waiting_on_decision":
      return "Waiting";
    case "validated":
      return "Validated";
    case "ready":
    default:
      return "Queued";
  }
}

function mapHealth(
  status: TaskStatus,
  blockerStatus: string | undefined,
  queuedCount: number,
  lastUpdated: string | undefined
): TaskHealth {
  if (status === "blocked" || (blockerStatus && blockerStatus !== "none")) {
    return "Blocked";
  }
  if (status === "waiting_on_decision") {
    return "Waiting on Decision";
  }
  if (lastUpdated) {
    const daysOld =
      (Date.now() - new Date(lastUpdated).getTime()) / (1000 * 60 * 60 * 24);
    if (daysOld > 7) {
      return "Stale";
    }
  }
  if (queuedCount <= 1 && status !== "validated") {
    return "Needs Reframe";
  }
  return "Healthy";
}

function toMilestoneRefs(
  queue:
    | Array<{
        milestone_id?: string;
        milestone_title?: string;
      }>
    | undefined
): MilestoneRef[] {
  if (!Array.isArray(queue)) {
    return [];
  }

  return queue
    .map((entry) => ({
      id: entry?.milestone_id || "unknown-milestone",
      title: entry?.milestone_title || "Untitled milestone",
    }))
    .filter((entry) => entry.id || entry.title);
}

function normaliseArtifacts(
  repoRoot: string,
  taskDir: string,
  manifest: ArtifactsManifestShape | null
): ArtifactRecord[] {
  if (!manifest?.artifacts || !Array.isArray(manifest.artifacts)) {
    return [];
  }

  return manifest.artifacts
    .filter((entry) => entry.path)
    .map((entry) => {
      const absolutePath = path.resolve(repoRoot, entry.path || "");
      return {
        path: entry.path || "",
        absolutePath,
        kind: entry.type || "artifact",
        reason: entry.reason || "",
        milestoneId: entry.milestone_id,
      };
    });
}

async function loadFindings(taskDir: string): Promise<TaskBoardItem["findings"]> {
  const findingsDir = path.join(taskDir, "findings");
  if (!(await exists(findingsDir))) {
    return [];
  }

  const entries = await fs.readdir(findingsDir, { withFileTypes: true });
  const files = entries
    .filter((entry) => entry.isFile())
    .map((entry) => path.join(findingsDir, entry.name))
    .sort((a, b) => a.localeCompare(b));

  return files.map((absolutePath) => ({
    title: path.basename(absolutePath, path.extname(absolutePath)),
    absolutePath,
    relativePath: path.relative(taskDir, absolutePath),
  }));
}

async function loadTask(
  repoRoot: string,
  taskDir: string
): Promise<TaskBoardItem | null> {
  const taskSlug = path.basename(taskDir);
  const files = {
    taskDir,
    checkpoints: path.join(taskDir, "checkpoints.json"),
    handoff: path.join(taskDir, "handoff.md"),
    progress: path.join(taskDir, "progress.md"),
    plan: path.join(taskDir, "plan.md"),
    runbook: path.join(taskDir, "runbook.md"),
    artifactsManifest: path.join(taskDir, "artifacts.json"),
  };

  const parseWarnings: string[] = [];
  for (const required of REQUIRED_FILES) {
    const requiredPath = path.join(taskDir, required);
    if (!(await exists(requiredPath))) {
      parseWarnings.push(`Missing required file: ${required}`);
    }
  }

  let checkpoints: CheckpointsShape = {};
  try {
    checkpoints = await readJson<CheckpointsShape>(files.checkpoints);
  } catch (error) {
    parseWarnings.push(
      `Unable to parse checkpoints.json: ${error instanceof Error ? error.message : String(error)}`
    );
  }

  const [hasHandoff, hasProgress, hasPlan, hasRunbook] = await Promise.all([
    exists(files.handoff),
    exists(files.progress),
    exists(files.plan),
    exists(files.runbook),
  ]);

  const [handoffMarkdown, progressMarkdown, planMarkdown, runbookMarkdown] =
    await Promise.all([
      hasHandoff ? readText(files.handoff) : Promise.resolve(""),
      hasProgress ? readText(files.progress) : Promise.resolve(""),
      hasPlan ? readText(files.plan) : Promise.resolve(""),
      hasRunbook ? readText(files.runbook) : Promise.resolve(""),
    ]);

  let artifactsManifest: ArtifactsManifestShape | null = null;
  try {
    artifactsManifest = (await exists(files.artifactsManifest))
      ? await readJson<ArtifactsManifestShape>(files.artifactsManifest)
      : null;
  } catch (error) {
    parseWarnings.push(
      `Unable to parse artifacts.json: ${error instanceof Error ? error.message : String(error)}`
    );
  }

  const currentMilestone =
    checkpoints.current?.milestone_id || checkpoints.current?.milestone_title
      ? {
          id: checkpoints.current?.milestone_id || "current",
          title:
            checkpoints.current?.milestone_title ||
            checkpoints.current?.slice_title ||
            "Untitled milestone",
        }
      : null;

  const queuedMilestones = toMilestoneRefs(
    checkpoints.execution?.queued_milestones
  );
  const status = checkpoints.status || "ready";
  const lastValidation =
    checkpoints.validation && checkpoints.validation.length > 0
      ? checkpoints.validation[checkpoints.validation.length - 1]
      : null;

  return {
    id: `${repoRoot}::${taskSlug}`,
    repoRoot,
    repoName: path.basename(repoRoot),
    taskSlug: checkpoints.task_slug || taskSlug,
    objective:
      checkpoints.objective ||
      extractBulletValue(planMarkdown, "Objective") ||
      "No objective recorded yet.",
    status,
    column: mapColumn(status),
    health: mapHealth(
      status,
      checkpoints.blocker?.status,
      queuedMilestones.length,
      checkpoints.last_updated
    ),
    currentMilestone,
    queuedMilestones,
    execution: {
      mode: checkpoints.execution?.mode || "single_milestone",
      runStyle: checkpoints.execution?.run_style || "bounded",
      planningSliceMinutes:
        checkpoints.execution?.planning_slice_minutes ?? null,
      runtimeBudgetMinutes: checkpoints.execution?.runtime_budget_minutes ?? null,
      targetQueueDepth: checkpoints.execution?.target_queue_depth ?? null,
    },
    blocker: checkpoints.blocker
      ? {
          status: checkpoints.blocker.status ?? null,
          type: checkpoints.blocker.type ?? null,
          summary: checkpoints.blocker.summary ?? null,
          attempts: checkpoints.blocker.attempts ?? null,
          nextAction: checkpoints.blocker.next_action ?? null,
        }
      : null,
    validation: lastValidation
      ? {
          type: lastValidation.type ?? null,
          summary: lastValidation.summary ?? null,
          timestamp: lastValidation.timestamp ?? checkpoints.last_updated ?? null,
          totalCount: checkpoints.validation?.length ?? 0,
        }
      : {
          type: null,
          summary: null,
          timestamp: checkpoints.last_updated ?? null,
          totalCount: checkpoints.validation?.length ?? 0,
        },
    lastRun: {
      stopReason: checkpoints.last_run?.stop_reason ?? null,
      events: checkpoints.last_run?.events ?? [],
      summary: checkpoints.last_run?.summary ?? null,
      startedAt: checkpoints.last_run?.started_at ?? null,
      endedAt: checkpoints.last_run?.ended_at ?? null,
      nextStep: checkpoints.last_run?.next_step ?? null,
    },
    handoff: {
      nextSlice:
        extractBulletValue(handoffMarkdown, "Next slice") ||
        checkpoints.current?.slice_title ||
        null,
      resumePrompt: findSection(handoffMarkdown, "Resume Prompt"),
      markdown: handoffMarkdown,
    },
    progressMarkdown,
    planMarkdown,
    runbookMarkdown,
    artifacts: normaliseArtifacts(repoRoot, taskDir, artifactsManifest),
    findings: await loadFindings(taskDir),
    files,
    parseWarnings,
    lastUpdated: checkpoints.last_updated ?? null,
  };
}

export async function discoverRepoRoots(explicitRoots?: string[]): Promise<string[]> {
  if (explicitRoots && explicitRoots.length > 0) {
    return explicitRoots;
  }

  let cursor = process.cwd();
  let repoRoot = cursor;

  while (true) {
    const hasAutonomous = await exists(path.join(cursor, ".autonomous"));
    const hasGit = await exists(path.join(cursor, ".git"));
    if (hasAutonomous || hasGit) {
      repoRoot = cursor;
      break;
    }

    const parent = path.dirname(cursor);
    if (parent === cursor) {
      repoRoot = process.cwd();
      break;
    }
    cursor = parent;
  }

  const examplesRoot = path.join(repoRoot, "examples/basic-workspace");
  const defaults = [repoRoot];

  if (await exists(path.join(examplesRoot, ".autonomous"))) {
    defaults.push(examplesRoot);
  }

  return defaults;
}

export async function loadBoardPayload(repoRoots: string[]): Promise<BoardPayload> {
  const repos: RepoInfo[] = [];
  const tasks: TaskBoardItem[] = [];

  for (const repoRoot of repoRoots) {
    const autonomousRoot = path.join(repoRoot, ".autonomous");
    if (!(await exists(autonomousRoot))) {
      repos.push({
        root: repoRoot,
        name: path.basename(repoRoot),
        taskCount: 0,
      });
      continue;
    }

    const entries = await fs.readdir(autonomousRoot, { withFileTypes: true });
    const taskDirs = entries
      .filter((entry) => entry.isDirectory())
      .map((entry) => path.join(autonomousRoot, entry.name))
      .sort((a, b) => a.localeCompare(b));

    for (const taskDir of taskDirs) {
      const task = await loadTask(repoRoot, taskDir);
      if (task) {
        tasks.push(task);
      }
    }

    repos.push({
      root: repoRoot,
      name: path.basename(repoRoot),
      taskCount: taskDirs.length,
    });
  }

  return {
    generatedAt: new Date().toISOString(),
    repos,
    tasks: tasks.sort((a, b) => {
      if (a.column !== b.column) {
        return a.column.localeCompare(b.column);
      }
      return a.taskSlug.localeCompare(b.taskSlug);
    }),
  };
}

export function isPathInsideRoots(candidatePath: string, repoRoots: string[]): boolean {
  return repoRoots.some((root) => {
    const relativePath = path.relative(root, candidatePath);
    return (
      relativePath !== "" &&
      !relativePath.startsWith("..") &&
      !path.isAbsolute(relativePath)
    );
  });
}
