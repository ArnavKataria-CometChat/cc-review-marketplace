// Connects the app user into CometChat whenever the auth session changes, and
// mounts the app-wide incoming-call overlay so a call rings anywhere in the app
// (not just on the Chat page). Gates a `ready` flag so CometChat components only
// render AFTER init+login completes (avoids "uiKitSettings not available").

import { createContext, useContext, useEffect, useState } from "react";
import type { ReactNode } from "react";

import { CometChatIncomingCall } from "@cometchat/chat-uikit-react";

import { useAuth } from "../auth/AuthContext";
import { connectCometChat, disconnectCometChat } from "./connection";
import { formatCometChatError } from "./errors";

interface CometChatState {
  ready: boolean;
  error: string | null;
}

const Ctx = createContext<CometChatState>({ ready: false, error: null });

export function CometChatProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    if (!user) {
      setReady(false);
      setError(null);
      void disconnectCometChat();
      return;
    }
    setReady(false);
    setError(null);
    connectCometChat()
      .then(() => {
        if (active) setReady(true);
      })
      .catch((e) => {
        if (active) setError(formatCometChatError(e));
      });
    return () => {
      active = false;
    };
  }, [user]);

  return (
    <Ctx.Provider value={{ ready, error }}>
      {children}
      {/* CometChatIncomingCall does NOT position itself — rendered bare it flows
          to the BOTTOM of the document (below the fold), so an incoming call is
          easy to miss entirely. Pin it as a fixed top-right overlay instead. */}
      {ready && (
        <div className="cc-incoming-call-overlay">
          <CometChatIncomingCall />
        </div>
      )}
    </Ctx.Provider>
  );
}

export function useCometChat(): CometChatState {
  return useContext(Ctx);
}
