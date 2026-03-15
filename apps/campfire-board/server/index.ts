import cors from "cors";
import express from "express";
import chokidar from "chokidar";
import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { discoverRepoRoots, isPathInsideRoots, loadBoardPayload } from "./task-store.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const apiPort = Number(process.env.CAMPFIRE_BOARD_API_PORT || 4319);
const repoRoots = (
  await discoverRepoRoots(
    process.env.CAMPFIRE_BOARD_REPOS
      ? process.env.CAMPFIRE_BOARD_REPOS.split(",")
          .map((entry) => entry.trim())
          .filter(Boolean)
      : undefined
  )
).map((entry) => path.resolve(entry));

const app = express();
app.use(cors());
app.use(express.json());

type EventClient = {
  id: string;
  response: express.Response;
};

const clients = new Map<string, EventClient>();

function sendEvent(event: string, payload: unknown) {
  const chunk = `event: ${event}\ndata: ${JSON.stringify(payload)}\n\n`;
  for (const { response } of clients.values()) {
    response.write(chunk);
  }
}

app.get("/api/board", async (_request, response) => {
  const payload = await loadBoardPayload(repoRoots);
  response.json(payload);
});

app.get("/api/raw", async (request, response) => {
  const requestedPath = request.query.path;
  if (typeof requestedPath !== "string") {
    response.status(400).json({ error: "Missing path query parameter." });
    return;
  }

  const resolvedPath = path.resolve(requestedPath);
  if (!isPathInsideRoots(resolvedPath, repoRoots)) {
    response.status(403).json({ error: "Requested file is outside configured repo roots." });
    return;
  }

  try {
    const content = await fs.readFile(resolvedPath, "utf8");
    response.type("text/plain").send(content);
  } catch (error) {
    response.status(404).json({
      error: error instanceof Error ? error.message : "Unable to read file.",
    });
  }
});

app.get("/api/events", (request, response) => {
  response.setHeader("Content-Type", "text/event-stream");
  response.setHeader("Cache-Control", "no-cache, no-transform");
  response.setHeader("Connection", "keep-alive");
  response.flushHeaders();

  const clientId = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  clients.set(clientId, { id: clientId, response });
  response.write(
    `event: ready\ndata: ${JSON.stringify({ connectedAt: new Date().toISOString() })}\n\n`
  );

  request.on("close", () => {
    clients.delete(clientId);
  });
});

const clientBuildCandidates = [
  path.resolve(__dirname, "../dist/client"),
  path.resolve(__dirname, "../../client"),
];

for (const clientBuildDir of clientBuildCandidates) {
  const clientIndex = path.join(clientBuildDir, "index.html");

  try {
    await fs.access(clientIndex);
    app.use(express.static(clientBuildDir));
    app.get("*", async (request, response, next) => {
      if (request.path.startsWith("/api/")) {
        next();
        return;
      }

      response.sendFile(clientIndex);
    });
    break;
  } catch {
    // Try the next candidate. In dev, the Vite server owns frontend assets.
  }
}

const watchTargets = repoRoots.map((root) => path.join(root, ".autonomous"));
const watcher = chokidar.watch(watchTargets, {
  ignoreInitial: true,
  awaitWriteFinish: {
    stabilityThreshold: 150,
    pollInterval: 50,
  },
});

watcher.on("all", async (eventName, changedPath) => {
  sendEvent("tasks-changed", {
    eventName,
    changedPath,
    timestamp: new Date().toISOString(),
  });
});

app.listen(apiPort, "127.0.0.1", () => {
  console.log(
    `Campfire Board API listening on http://127.0.0.1:${apiPort} for roots: ${repoRoots.join(", ")}`
  );
});
