import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import path from "node:path";
import process from "node:process";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";
import { _electron as electron } from "playwright";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const appRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(appRoot, "../..");
const exampleRoot = path.join(repoRoot, "examples/basic-workspace");
const apiPort = Number(process.env.CAMPFIRE_BOARD_SMOKE_PORT || 4329);
const apiUrl = `http://127.0.0.1:${apiPort}`;
const serverEntry = path.join(appRoot, "dist/server/server/index.js");
const serverLogs = [];

function pushLog(prefix, chunk) {
  const text = chunk.toString().trim();
  if (!text) {
    return;
  }

  for (const line of text.split("\n")) {
    serverLogs.push(`${prefix}${line}`);
  }

  while (serverLogs.length > 40) {
    serverLogs.shift();
  }
}

function startServer() {
  const child = spawn(process.execPath, [serverEntry], {
    cwd: appRoot,
    env: {
      ...process.env,
      CAMPFIRE_BOARD_API_PORT: String(apiPort),
      CAMPFIRE_BOARD_REPOS: [repoRoot, exampleRoot].join(","),
    },
    stdio: ["ignore", "pipe", "pipe"],
  });

  child.stdout.on("data", (chunk) => pushLog("[server] ", chunk));
  child.stderr.on("data", (chunk) => pushLog("[server] ", chunk));

  return child;
}

async function waitForHttp(url, timeoutMs = 15000) {
  const startedAt = Date.now();

  while (Date.now() - startedAt < timeoutMs) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return;
      }
    } catch {
      // Keep polling until the timeout expires.
    }

    await delay(200);
  }

  throw new Error(`Timed out waiting for ${url}\n${serverLogs.join("\n")}`);
}

async function waitForCondition(check, label, timeoutMs = 5000) {
  const startedAt = Date.now();

  while (Date.now() - startedAt < timeoutMs) {
    if (await check()) {
      return;
    }

    await delay(100);
  }

  throw new Error(`Timed out waiting for ${label}`);
}

async function stopChild(child) {
  if (!child || child.killed || child.exitCode !== null) {
    return;
  }

  child.kill("SIGTERM");

  const startedAt = Date.now();
  while (child.exitCode === null && Date.now() - startedAt < 3000) {
    await delay(100);
  }

  if (child.exitCode === null) {
    child.kill("SIGKILL");
  }
}

const server = startServer();
let electronApp;

try {
  await waitForHttp(`${apiUrl}/api/board`);

  const boardResponse = await fetch(`${apiUrl}/api/board`);
  const boardPayload = await boardResponse.json();
  assert(boardPayload.tasks.length > 0, "Expected at least one Campfire task on the board.");

  electronApp = await electron.launch({
    cwd: appRoot,
    args: ["electron/main.mjs"],
    env: {
      ...process.env,
      CAMPFIRE_BOARD_DESKTOP_URL: apiUrl,
      CAMPFIRE_BOARD_API_PORT: String(apiPort),
      CAMPFIRE_BOARD_REPOS: [repoRoot, exampleRoot].join(","),
    },
  });

  const appWindow = await electronApp.firstWindow();
  await appWindow.waitForSelector(".topbar");
  await appWindow.waitForSelector(".card");

  assert.equal(await appWindow.locator(".lane").count(), 4, "Expected four widget lanes.");
  assert(
    (await appWindow.locator(".card").count()) > 0,
    "Expected at least one task card in the widget."
  );

  const topbarRegion = await appWindow.locator(".topbar").evaluate((element) => {
    const styles = getComputedStyle(element);
    return styles.getPropertyValue("-webkit-app-region") || styles.webkitAppRegion || "";
  });
  assert.match(topbarRegion.trim(), /drag/, "Top bar should stay draggable.");

  const pinButton = appWindow.getByRole("button", { name: "Pin" });
  assert.equal(await pinButton.count(), 1, "Expected the Pin control to be visible.");

  const pinRegion = await pinButton.evaluate((element) => {
    const styles = getComputedStyle(element);
    return styles.getPropertyValue("-webkit-app-region") || styles.webkitAppRegion || "";
  });
  assert.match(pinRegion.trim(), /no-drag/, "Pin button must remain clickable.");

  assert.equal(
    await pinButton.getAttribute("aria-pressed"),
    "false",
    "Pin should default to off."
  );

  await pinButton.click();
  await waitForCondition(
    async () => (await pinButton.getAttribute("aria-pressed")) === "true",
    "pin toggle to turn on"
  );
  assert.equal(
    await appWindow.evaluate(() => window.campfireBoardDesktop?.getAlwaysOnTop?.()),
    true,
    "Electron window should report always-on-top after pinning."
  );

  await pinButton.click();
  await waitForCondition(
    async () => (await pinButton.getAttribute("aria-pressed")) === "false",
    "pin toggle to turn off"
  );
  assert.equal(
    await appWindow.evaluate(() => window.campfireBoardDesktop?.getAlwaysOnTop?.()),
    false,
    "Electron window should report normal stacking after unpinning."
  );

  const repoPicker = appWindow.locator("select");
  assert.equal(await repoPicker.count(), 1, "Expected repo picker when multiple roots are present.");

  const options = await repoPicker.locator("option").evaluateAll((elements) =>
    elements.map((element) => ({
      value: element.getAttribute("value") || "",
      label: element.textContent?.trim() || "",
    }))
  );
  assert(options.length >= 3, "Expected all-repos plus the two configured roots.");

  const targetRepo = options.find((option) => option.value !== "all");
  assert(targetRepo, "Expected a selectable repo-specific filter.");
  await repoPicker.selectOption(targetRepo.value);

  await waitForCondition(
    async () => (await appWindow.locator(".card").count()) > 0,
    "repo-filtered cards"
  );

  assert.equal(
    await appWindow.getByRole("button", { name: "Copy prompt" }).count(),
    1,
    "Selected task should expose Copy prompt."
  );

  assert.equal(
    await appWindow.getByRole("link", { name: "Handoff" }).count(),
    1,
    "Selected task should expose the Handoff link."
  );

  console.log("Campfire Board Electron smoke test passed.");
} finally {
  await electronApp?.close().catch(() => {});
  await stopChild(server);
}
