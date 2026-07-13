// Pretty-print CometChat SDK errors. A raw `CometChatException` looks like
// `{ code, message, details, source }` (or `{ errorCode, errorDescription }` in
// some kit versions), so `String(e)` renders "[object Object]" — useless when it
// surfaces in the UI. Always route kit errors through these helpers.

export function formatCometChatError(e: unknown): string {
  if (e == null) return "Unknown CometChat error.";
  const err = e as Record<string, unknown>;
  const code = (err.code as string | undefined) ?? (err.errorCode as string | undefined);
  const message =
    (err.message as string | undefined) ?? (err.errorDescription as string | undefined);
  if (code && message) return `[CometChat ${code}] ${message}`;
  if (message) return `[CometChat] ${message}`;
  try {
    return `[CometChat] ${JSON.stringify(e)}`;
  } catch {
    return `[CometChat] ${String(e)}`;
  }
}

// Human hints for the error codes an integrator is most likely to hit here.
const KNOWN_DOC_HINTS: Record<string, string> = {
  ERR_UID_NOT_FOUND:
    "The other party hasn't activated chat yet — their CometChat user is provisioned the first time they open the app.",
  ERR_AUTH_TOKEN_NOT_FOUND:
    "Auth token is empty or expired. It is minted per-session by the backend at POST /cometchat/token.",
  ERR_GUID_NOT_FOUND:
    "The dispute group doesn't exist yet — it is created by the backend when a report is flagged.",
};

export function logCometChatError(e: unknown): void {
  const formatted = formatCometChatError(e);
  console.error(formatted, e);
  const code =
    (e as { code?: string; errorCode?: string })?.code ??
    (e as { code?: string; errorCode?: string })?.errorCode;
  if (code && KNOWN_DOC_HINTS[code]) {
    console.warn(`[CometChat hint] ${KNOWN_DOC_HINTS[code]}`);
  }
}
