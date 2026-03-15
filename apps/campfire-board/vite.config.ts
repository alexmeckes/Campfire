import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const apiPort = Number(process.env.CAMPFIRE_BOARD_API_PORT || 4319);

export default defineConfig({
  plugins: [react()],
  server: {
    host: "127.0.0.1",
    port: 4173,
    proxy: {
      "/api": `http://127.0.0.1:${apiPort}`,
    },
  },
  preview: {
    host: "127.0.0.1",
    port: 4173,
  },
  build: {
    outDir: "dist/client",
    emptyOutDir: true,
  },
});

