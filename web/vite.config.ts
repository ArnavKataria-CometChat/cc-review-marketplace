import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// The API base URL is read at build time from VITE_API_BASE_URL (see .env.example).
// A dev proxy lets `npm run dev` talk to a locally-running backend on :8080
// without CORS config; production builds call VITE_API_BASE_URL directly.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:8080",
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ""),
      },
    },
  },
});
