import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";

import { App } from "./App";
import { AuthProvider } from "./auth/AuthContext";
import { CometChatProvider } from "./cometchat/CometChatProvider";
import "./styles.css";

const rootEl = document.getElementById("root");
if (!rootEl) throw new Error("root element not found");

createRoot(rootEl).render(
  <StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <CometChatProvider>
          <App />
        </CometChatProvider>
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>,
);
