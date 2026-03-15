/// <reference types="vite/client" />

interface CampfireBoardDesktopApi {
  mode: "electron";
  getAlwaysOnTop?: () => Promise<boolean>;
  setAlwaysOnTop?: (nextValue: boolean) => Promise<boolean>;
}

interface Window {
  campfireBoardDesktop?: CampfireBoardDesktopApi;
}
