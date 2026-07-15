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

import { CometChatUIKit, UIKitSettingsBuilder } from "@cometchat/chat-uikit-react";
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
export async function endHangingCall(reason: string): Promise<void> {
  try {
    const active = CometChat.getActiveCall();
    if (!active) return;
    const liveSurface = document.querySelector(
      ".cometchat-ongoing-call, [class*='cometchat-ongoing-call']");
    if (liveSurface) return; // a real call is on screen — leave it alone
    const sid = active.getSessionId?.();
    console.log(`[cometchat] ending hanging ghost call (${reason}): ${sid}`);
    if (sid) await CometChat.endCall(sid).catch(() => undefined);
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
          const active = CometChat.getActiveCall();
          const incomingSid = (call as { getSessionId?: () => string })?.getSessionId?.();
          if (active && active.getSessionId?.() !== incomingSid) {
            void endHangingCall("incoming-ring sweep");
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
