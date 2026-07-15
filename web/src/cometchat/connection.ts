// CometChat UIKit connection lifecycle for the web app.
//
// Bootstrap is credential-free on the client: the backend (POST /cometchat/token)
// returns the non-secret App ID + Region and a short-lived per-user auth token.
// We init the UIKit with those, then log in with the token. The REST/Auth keys
// never touch the browser.
//
// CALLING: the UIKit settings are built with `.enableCalling()` — WITHOUT it the
// calling components (header call buttons, incoming-call overlay, ongoing-call
// surface) throw "uiKitSettings not available" and calls never connect. Init MUST
// complete before any CometChat component mounts (callers gate on connect()).

import { CometChatUIKit, UIKitSettingsBuilder, CometChatCallEvents } from "@cometchat/chat-uikit-react";
import { CometChat } from "@cometchat/chat-sdk-javascript";
import { getCometChatToken } from "../api/endpoints";

let initedFor: string | null = null; // `${appId}:${region}` the UIKit was init'd for
let connectedUid: string | null = null;
let inFlight: Promise<string> | null = null;

async function ensureInit(appId: string, region: string): Promise<void> {
  const key = `${appId}:${region}`;
  if (initedFor === key) return;
  // Calling is enabled by default in UIKit v6 (there is only `disableCalling()`),
  // so the header call buttons + incoming/ongoing call surfaces are available as
  // long as init() has completed before any component mounts — callers gate on
  // connect(), and the provider only renders chat components once ready. That
  // ordering is what fixes the "uiKitSettings not available" error.
  const settings = new UIKitSettingsBuilder()
    .setAppId(appId)
    .setRegion(region)
    .subscribePresenceForAllUsers()
    .build();
  await CometChatUIKit.init(settings);
  initedFor = key;
}

/**
 * Ensure the UIKit is initialized and the current app user is logged into
 * CometChat. Idempotent: returns the connected uid; a second call for the same
 * user is a no-op. Safe to call on every auth change.
 */
export async function connectCometChat(): Promise<string> {
  if (inFlight) return inFlight;
  inFlight = (async () => {
    const token = await getCometChatToken(); // { appId, region, uid, authToken }
    await ensureInit(token.appId, token.region);
    const existing = await CometChatUIKit.getLoggedinUser();
    if (existing && existing.getUid() === token.uid) {
      connectedUid = token.uid;
      return token.uid;
    }
    if (existing) {
      await CometChatUIKit.logout().catch(() => undefined);
    }
    await CometChatUIKit.loginWithAuthToken(token.authToken);
    // [GHOST-SWEEP] End any STALE/ghost active call left from a previous
    // page/session — SERVER-SIDE too (clearActiveCall alone is client-local).
    // A hanging ghost reports this user BUSY: fresh rings auto-reject and an
    // accepted call is torn down instantly by the ghost's late end-event.
    await endHangingCall("connect-time sweep");
    installCallLifecycleGuards();
    connectedUid = token.uid;
    return token.uid;
  })();
  try {
    return await inFlight;
  } finally {
    inFlight = null;
  }
}

// [W11] Release call sessions so a dropped client can't wedge the pair BUSY.
// Without these, NO code path ever calls CometChat.endCall/clearActiveCall
// after a call ends abnormally: a tab close (or crashed/killed browser) leaves
// the session ongoing server-side and every subsequent call to either party is
// instantly auto-rejected "Call Busy" until the zombie expires. Web analog of
// the catalog's I4 (iOS) / A4 (Android) ghost-call entries.
/**
 * [GHOST-SWEEP] End a hanging/ghost call: server-side endCall + local
 * clearActiveCall. Never touches a REAL in-progress call — the kit's
 * ongoing-call surface being mounted is the liveness signal.
 */
export async function endHangingCall(reason: string, protectSid?: string): Promise<void> {
  try {
    const active = CometChat.getActiveCall();
    if (!active) return;
    const liveSurface = document.querySelector(
      ".cometchat-ongoing-call, [class*='cometchat-ongoing-call'], " +
      ".cometchat-outgoing-call, .cometchat-incoming-call");
    if (liveSurface) return; // ANY live call UI (ringing included) — leave it alone
    const sid = active.getSessionId?.() ?? (active as { sessionId?: string }).sessionId;
    if (!sid) { CometChat.clearActiveCall(); return; }
    if (protectSid && sid === protectSid) return; // NEVER end the fresh call
    console.log(`[cometchat] ending hanging ghost call (${reason}): ${sid}`);
    await CometChat.endCall(sid).catch(() => undefined);
    CometChat.clearActiveCall();
  } catch { /* ignore */ }
}

let lifecycleInstalled = false;
function installCallLifecycleGuards(): void {
  if (lifecycleInstalled) return;
  lifecycleInstalled = true;
  CometChat.addCallListener(
    "marketplace.call.lifecycle",
    new CometChat.CallListener({
      // [GHOST-SWEEP] a fresh ring while a ghost hangs: end the ghost NOW so
      // this call isn't auto-rejected busy / cut on accept.
      onIncomingCallReceived: (call: unknown) => {
        try {
          const c = call as { getSessionId?: () => string; sessionId?: string };
          const incomingSid = c?.getSessionId?.() ?? c?.sessionId;
          const active = CometChat.getActiveCall();
          const activeSid = active?.getSessionId?.()
            ?? (active as { sessionId?: string } | null)?.sessionId;
          // Sweep ONLY when both ids exist and genuinely differ — a missing id
          // must never be treated as a mismatch (that killed fresh calls: the
          // sweep ended the very call that was ringing).
          if (incomingSid && activeSid && activeSid !== incomingSid) {
            void endHangingCall("incoming-ring sweep", incomingSid);
          }
        } catch { /* ignore */ }
      },
      onIncomingCallCancelled: () => {
        try { CometChat.clearActiveCall(); } catch { /* ignore */ }
      },
      onCallEndedMessageReceived: () => {
        try { CometChat.clearActiveCall(); } catch { /* ignore */ }
      },
    }),
  );
  // [CALL-END HYGIENE] The SDK CallListener above only covers REMOTE events.
  // When the LOCAL user presses End, neither fires — activeCall lingered on
  // the ender's side and busy-rejected the NEXT call ("one call works, after
  // that it doesn't"). The kit's own event bus fires on the LOCAL side too.
  CometChatCallEvents.ccCallEnded.subscribe(() => {
    try { CometChat.clearActiveCall(); } catch { /* ignore */ }
  });
  CometChatCallEvents.ccCallRejected.subscribe(() => {
    try { CometChat.clearActiveCall(); } catch { /* ignore */ }
  });
  // Best-effort server-side release when the page goes away mid-call.
  window.addEventListener("beforeunload", () => {
    try {
      const active = CometChat.getActiveCall();
      if (active) void CometChat.endCall(active.getSessionId());
    } catch { /* ignore */ }
  });
}

/** Log the current user out of CometChat (best-effort) — call on app logout. */
export async function disconnectCometChat(): Promise<void> {
  connectedUid = null;
  try {
    const u = await CometChatUIKit.getLoggedinUser();
    if (u) await CometChatUIKit.logout();
  } catch {
    /* ignore */
  }
}

export const cometChatConnectedUid = (): string | null => connectedUid;
