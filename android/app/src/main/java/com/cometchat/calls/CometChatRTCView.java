package com.cometchat.calls;

/**
 * No-op stub for a legacy (V3-era) class the CometChat Chat SDK's CallManager
 * references at bytecode level. calls-sdk-android 5.x moved everything to
 * com.cometchat.calls.core.* and dropped this path; without a local stub the
 * first call attempt fails class verification (NoClassDefFoundError). Never
 * invoked at runtime — the real call surface uses com.cometchat.calls.core.*.
 *
 * NOTE: only the classes actually MISSING from calls-sdk 5.x are stubbed here.
 * RTCUser is intentionally NOT stubbed — it still ships in calls-sdk-android
 * 5.x, so a stub would collide at dex time (Duplicate class).
 */
public class CometChatRTCView {
}
