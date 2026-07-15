import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// The API base URL is read at build time from VITE_API_BASE_URL (see .env.example).
// A dev proxy lets `npm run dev` talk to a locally-running backend on :8080
// without CORS config; production builds call VITE_API_BASE_URL directly.
export default defineConfig({
  plugins: [react()],
  build: {
    // [W6-ROOT] @cometchat/chat-uikit-react's ESM dist resolves the calls SDK
    // via a bare CommonJS require() wrapped in try/catch. Under a plain Vite
    // ESM build `require` is undefined, the throw is swallowed, and
    // enableCalling() silently no-ops — calls signal but NEVER connect (no
    // RTCPeerConnection is ever constructed). transformMixedEsModules makes
    // the rollup commonjs plugin convert that require() into a bundled import
    // so the calls SDK actually loads.
    commonjsOptions: { transformMixedEsModules: true },
  },
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
