import { contextBridge, ipcRenderer } from "electron";

contextBridge.exposeInMainWorld("campfireBoardDesktop", {
  mode: "electron",
  getAlwaysOnTop: () => ipcRenderer.invoke("campfire-board:get-always-on-top"),
  setAlwaysOnTop: (nextValue) =>
    ipcRenderer.invoke("campfire-board:set-always-on-top", nextValue),
});
