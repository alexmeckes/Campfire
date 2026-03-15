import { app, BrowserWindow, ipcMain, shell } from "electron";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const desktopUrl =
  process.env.CAMPFIRE_BOARD_DESKTOP_URL || "http://127.0.0.1:4319";

let mainWindow;

function currentAlwaysOnTop() {
  return mainWindow?.isAlwaysOnTop() ?? false;
}

function setAlwaysOnTop(nextValue) {
  if (!mainWindow) {
    return false;
  }

  mainWindow.setAlwaysOnTop(nextValue, nextValue ? "floating" : "normal");
  return mainWindow.isAlwaysOnTop();
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 560,
    height: 420,
    minWidth: 520,
    minHeight: 380,
    backgroundColor: "#f6efe6",
    titleBarStyle: "hiddenInset",
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.mjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: "deny" };
  });

  mainWindow.loadURL(desktopUrl);
}

app.whenReady().then(() => {
  ipcMain.handle("campfire-board:get-always-on-top", () => currentAlwaysOnTop());
  ipcMain.handle("campfire-board:set-always-on-top", (_event, nextValue) =>
    setAlwaysOnTop(Boolean(nextValue))
  );

  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
