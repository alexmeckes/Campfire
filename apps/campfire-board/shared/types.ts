export type TaskStatus =
  | "ready"
  | "in_progress"
  | "blocked"
  | "waiting_on_decision"
  | "validated";

export type BoardColumn =
  | "Queued"
  | "Active"
  | "Blocked"
  | "Waiting"
  | "Validated";

export type TaskHealth =
  | "Healthy"
  | "Needs Reframe"
  | "Blocked"
  | "Waiting on Decision"
  | "Stale";

export type MilestoneRef = {
  id: string;
  title: string;
};

export type ArtifactRecord = {
  path: string;
  absolutePath: string;
  kind: string;
  reason: string;
  milestoneId?: string;
};

export type FileLinkSet = {
  taskDir: string;
  checkpoints: string;
  handoff: string;
  progress: string;
  plan: string;
  runbook: string;
  artifactsManifest: string;
};

export type TaskBoardItem = {
  id: string;
  repoRoot: string;
  repoName: string;
  taskSlug: string;
  objective: string;
  status: TaskStatus;
  column: BoardColumn;
  health: TaskHealth;
  currentMilestone: MilestoneRef | null;
  queuedMilestones: MilestoneRef[];
  execution: {
    mode: "single_milestone" | "rolling";
    runStyle: "bounded" | "until_stopped";
    planningSliceMinutes: number | null;
    runtimeBudgetMinutes: number | null;
    targetQueueDepth: number | null;
  };
  blocker: {
    status: string | null;
    type: string | null;
    summary: string | null;
    attempts: number | null;
    nextAction: string | null;
  } | null;
  validation: {
    type: string | null;
    summary: string | null;
    timestamp: string | null;
    totalCount: number;
  } | null;
  lastRun: {
    stopReason: string | null;
    events: string[];
    summary: string | null;
    startedAt: string | null;
    endedAt: string | null;
    nextStep: string | null;
  };
  handoff: {
    nextSlice: string | null;
    resumePrompt: string | null;
    markdown: string;
  };
  progressMarkdown: string;
  planMarkdown: string;
  runbookMarkdown: string;
  artifacts: ArtifactRecord[];
  findings: {
    title: string;
    absolutePath: string;
    relativePath: string;
  }[];
  files: FileLinkSet;
  parseWarnings: string[];
  lastUpdated: string | null;
};

export type RepoInfo = {
  root: string;
  name: string;
  taskCount: number;
};

export type BoardPayload = {
  generatedAt: string;
  repos: RepoInfo[];
  tasks: TaskBoardItem[];
};

