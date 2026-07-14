import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";

import { App } from "./App";
import { AuthProvider } from "./auth/AuthContext";
import { CometChatProvider } from "./cometchat/CometChatProvider";

// CometChat UIKit v6 ships its design tokens (colours, spacing, typography, the
// icon set) as this stylesheet. WITHOUT it every kit component renders unstyled —
// no message bubbles, no avatars, icons/call-buttons collapse to blank boxes —
// even though the components still function. It MUST be imported once, app-wide,
// before our own overrides.
import "@cometchat/chat-uikit-react/css-variables.css";
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
