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
    // Clear any STALE/ghost active call left from a previous page/session. If the
    // SDK still holds an active call (e.g. a call surface that wasn't torn down),
    // this user is reported BUSY and every new incoming call auto-rejects as "Call
    // Busy" — the "call disconnects the moment it's initiated" symptom. A fresh
    // login can't have a legitimate active call, so clear it. (A page reload then
    // fixes a stuck-busy user.)
    try {
      if (CometChat.getActiveCall()) CometChat.clearActiveCall();
    } catch {
      /* ignore */
    }
    connectedUid = token.uid;
    return token.uid;
  })();
  try {
    return await inFlight;
  } finally {
    inFlight = null;
  }
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
