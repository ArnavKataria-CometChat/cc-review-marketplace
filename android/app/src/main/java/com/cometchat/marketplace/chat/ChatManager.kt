package com.cometchat.marketplace.chat

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.cometchat.calls.core.CallAppSettings
import com.cometchat.calls.core.CometChatCalls
import com.cometchat.chat.core.Call
import com.cometchat.chat.core.CometChat
import com.cometchat.chat.exceptions.CometChatException
import com.cometchat.marketplace.data.MarketplaceRepository
import com.cometchat.marketplace.data.Outcome
import com.cometchat.marketplace.ui.main.MainActivity
import com.cometchat.uikit.core.CometChatUIKit
import com.cometchat.uikit.core.UIKitSettings
import com.cometchat.uikit.core.events.CometChatCallEvent
import com.cometchat.uikit.core.events.CometChatEvents
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import java.lang.ref.WeakReference
import kotlin.coroutines.resume

/**
 * Owns the CometChat SDK lifecycle for the marketplace app.
 *
 * Bootstrap is credential-free on the client: [ensureReady] asks the backend
 * (POST /cometchat/token) for the non-secret App ID + Region and a short-lived
 * per-user auth token, initializes the Chat + Calls SDKs, and logs in with the
 * token. The CometChat REST key stays on the backend and never touches the app.
 *
 * Call lifecycle: the UI Kit's ongoing-call screen runs in its OWN task, so when
 * a call ends the OS returns to the launcher rather than to us. [install] wires
 * the two fixes for that:
 *   - [A3] local end  → CometChatCallEvent.CallEnded re-foregrounds MainActivity.
 *   - [A4] remote end → CometChat.CallListener.onCallEndedMessageReceived finishes
 *          the ongoing-call activity (own task), clears the active call, and
 *          re-foregrounds MainActivity (the UI Kit does none of this itself).
 */
object ChatManager {

    private const val TAG = "ChatManager"
    private const val CALL_LISTENER_ID = "marketplace_call_listener"
    private const val PREFS = "cometchat_boot"
    private const val KEY_APP_ID = "app_id"
    private const val KEY_REGION = "region"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private var app: Application? = null
    private var topActivity: WeakReference<Activity>? = null
    private var ongoingCallActivity: WeakReference<Activity>? = null

    @Volatile
    private var callListenerRegistered = false

    /**
     * The current incoming 1:1 call, or null when none is ringing.
     *
     * The hosted [CometChatIncomingCall] widget does NOT self-gate in UIKit
     * v6.0.3: mounted as an always-present overlay it renders its Accept/Decline
     * chrome even with no call bound, covering the conversation header (peer
     * name, back button, and the voice/video call buttons). So ChatActivity keeps
     * the widget GONE and only shows it while this flow is non-null. Set on
     * onIncomingCallReceived and cleared on cancel/reject/accept/end.
     */
    private val _incomingCall = MutableStateFlow<Call?>(null)
    val incomingCall: StateFlow<Call?> = _incomingCall.asStateFlow()

    /** Hide the incoming-call overlay (call after the user accepts/rejects). */
    fun clearIncomingCall() { _incomingCall.value = null }

    /** True once the SDK is initialized and a user is logged in. */
    val isLoggedIn: Boolean
        get() = CometChatUIKit.isSDKInitialized() && CometChatUIKit.getLoggedInUser() != null

    // --- App wiring (call once from Application.onCreate) --------------------

    fun install(application: Application) {
        app = application
        application.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                if (isCometChatCallActivity(activity)) ongoingCallActivity = WeakReference(activity)
            }

            override fun onActivityResumed(activity: Activity) {
                topActivity = WeakReference(activity)
                if (isCometChatCallActivity(activity)) ongoingCallActivity = WeakReference(activity)
            }

            override fun onActivityStarted(activity: Activity) {}
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })

        // [A7] The CometChat SDK MUST be initialized in every process (the calling
        // UI runs in its own process). App ID/Region come from the backend, so we
        // can't hardcode them — but once the first login has cached them, re-init
        // eagerly here (install runs from Application.onCreate in EVERY process).
        // Without this, a CometChat UIKit view mounting in the call process calls
        // into an uninitialized SDK (SQLiteManager) and crashes with
        // "Please call the CometChat.init() method ...".
        eagerInit(application)

        // [A3] When a call ends LOCALLY, the UI Kit's own-task ongoing-call screen
        // finishes back to the launcher. Bring our app forward instead.
        scope.launch {
            CometChatEvents.callEvents.collect { event ->
                when (event) {
                    is CometChatCallEvent.CallEnded -> {
                        _incomingCall.value = null
                        reForegroundApp()
                    }
                    is CometChatCallEvent.CallRejected -> _incomingCall.value = null
                    is CometChatCallEvent.CallAccepted -> _incomingCall.value = null
                    else -> Unit
                }
            }
        }
    }

    /**
     * [A7] Re-initialize the CometChat SDK in the current process if a prior login
     * cached the App ID/Region. Safe to call from Application.onCreate in every
     * process; no-op if the SDK is already up or no creds are cached yet (the
     * first-ever launch initializes lazily via [ensureReady] instead).
     */
    private fun eagerInit(context: Context) {
        if (CometChatUIKit.isSDKInitialized()) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val appId = prefs.getString(KEY_APP_ID, null) ?: return
        val region = prefs.getString(KEY_REGION, null) ?: return
        scope.launch {
            if (CometChatUIKit.isSDKInitialized()) return@launch
            if (initUiKit(context, appId, region)) {
                initCallsSdk(context, appId, region)
            }
        }
    }

    private fun cacheCreds(context: Context, appId: String, region: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_APP_ID, appId)
            .putString(KEY_REGION, region)
            .apply()
    }

    // --- Bootstrap ----------------------------------------------------------

    /**
     * Ensure the CometChat SDK is initialized and the current app user is logged
     * in. Idempotent and safe to call from any chat entry point. Returns false if
     * chat is unconfigured/unreachable so callers can degrade gracefully.
     */
    suspend fun ensureReady(context: Context, repo: MarketplaceRepository): Boolean {
        val appUid = repo.currentUser?.id
        if (isLoggedIn && appUid != null && CometChatUIKit.getLoggedInUser()?.uid == appUid) {
            registerCallListener()
            return true
        }

        val token = when (val r = repo.cometChatToken()) {
            is Outcome.Success -> r.data
            is Outcome.Error -> {
                Log.w(TAG, "cometchat token unavailable: ${r.message}")
                return false
            }
        }
        if (token.appId.isBlank() || token.authToken.isBlank()) return false

        // [A7] Persist the (non-secret) App ID/Region so Application.onCreate can
        // re-init the SDK in every process (incl. the separate call process).
        cacheCreds(context.applicationContext, token.appId, token.region)

        if (!CometChatUIKit.isSDKInitialized() && !initUiKit(context.applicationContext, token.appId, token.region)) {
            return false
        }

        // [X1] The calling (WebRTC) SDK is a SEPARATE init — the Chat/UIKit init
        // does NOT bring it up. Initialize it explicitly right after, or call
        // buttons render but calls stay stuck "connecting".
        initCallsSdk(context.applicationContext, token.appId, token.region)

        val loggedIn = CometChatUIKit.getLoggedInUser()?.uid == token.uid || loginWithToken(token.authToken)
        if (loggedIn) registerCallListener()
        return loggedIn
    }

    /** Log the current user out of CometChat (best-effort) — call on app logout. */
    fun logout() {
        if (!CometChatUIKit.isSDKInitialized() || CometChatUIKit.getLoggedInUser() == null) return
        CometChatUIKit.logout(object : CometChat.CallbackListener<String>() {
            override fun onSuccess(p0: String?) {}
            override fun onError(e: CometChatException?) {}
        })
    }

    // --- SDK init helpers ---------------------------------------------------

    private suspend fun initUiKit(context: Context, appId: String, region: String): Boolean =
        suspendCancellableCoroutine { cont ->
            val settings = UIKitSettings.UIKitSettingsBuilder()
                .setAppId(appId)
                .setRegion(region)
                .subscribePresenceForAllUsers()
                .setEnableCalling(true) // registers the calling extension → header call buttons
                .build()
            CometChatUIKit.init(context, settings, object : CometChat.CallbackListener<String>() {
                override fun onSuccess(p0: String?) { if (cont.isActive) cont.resume(true) }
                override fun onError(e: CometChatException?) {
                    Log.e(TAG, "UIKit init failed: ${e?.message}")
                    if (cont.isActive) cont.resume(false)
                }
            })
        }

    private suspend fun initCallsSdk(context: Context, appId: String, region: String) {
        if (CometChatUIKit.isCallsSDKInitialized()) return
        suspendCancellableCoroutine<Unit> { cont ->
            val callAppSettings = CallAppSettings.CallAppSettingBuilder()
                .setAppId(appId)
                .setRegion(region)
                .build()
            CometChatCalls.init(context, callAppSettings, object : CometChatCalls.CallbackListener<String>() {
                override fun onSuccess(p0: String?) { if (cont.isActive) cont.resume(Unit) }
                override fun onError(e: com.cometchat.calls.exceptions.CometChatException?) {
                    Log.e(TAG, "Calls init failed: ${e?.message}")
                    if (cont.isActive) cont.resume(Unit)
                }
            })
        }
    }

    private suspend fun loginWithToken(authToken: String): Boolean =
        suspendCancellableCoroutine { cont ->
            CometChatUIKit.loginWithAuthToken(authToken, object : CometChat.CallbackListener<com.cometchat.chat.models.User>() {
                override fun onSuccess(p0: com.cometchat.chat.models.User?) { if (cont.isActive) cont.resume(true) }
                override fun onError(e: CometChatException?) {
                    Log.e(TAG, "loginWithAuthToken failed: ${e?.message}")
                    if (cont.isActive) cont.resume(false)
                }
            })
        }

    // --- Call lifecycle -----------------------------------------------------

    private fun registerCallListener() {
        if (callListenerRegistered) return
        callListenerRegistered = true
        CometChat.addCallListener(CALL_LISTENER_ID, object : CometChat.CallListener() {
            override fun onIncomingCallReceived(call: Call?) {
                // Surface the ringing call so ChatActivity can SHOW the (otherwise
                // GONE) CometChatIncomingCall overlay. The widget does not gate
                // itself, so we drive its visibility off this state.
                _incomingCall.value = call
            }

            override fun onOutgoingCallAccepted(call: Call?) {}
            override fun onOutgoingCallRejected(call: Call?) {}

            override fun onIncomingCallCancelled(call: Call?) {
                // Caller hung up before we answered — hide the overlay.
                _incomingCall.value = null
            }

            override fun onCallEndedMessageReceived(call: Call?) {
                // [A4] The UI Kit's ongoing-call activity does NOT finish when the
                // REMOTE party ends a 1:1 call (only the LOCAL end fires the event
                // bus). Tear it down ourselves so we don't leave a ghost call.
                _incomingCall.value = null
                finishOngoingCallActivity()
                CometChat.clearActiveCall()
                reForegroundApp()
            }
        })
    }

    private fun finishOngoingCallActivity() {
        val activity = ongoingCallActivity?.get() ?: return
        if (!activity.isFinishing) {
            // The ongoing-call screen lives in its own task — finishAndRemoveTask
            // clears that task so it can't linger behind our app.
            activity.finishAndRemoveTask()
        }
        ongoingCallActivity = null
    }

    private fun reForegroundApp() {
        val context = topActivity?.get() ?: app ?: return
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    /** A CometChat-owned call activity (its own task) — tracked for teardown. */
    private fun isCometChatCallActivity(activity: Activity): Boolean {
        val name = activity.javaClass.name
        return name.startsWith("com.cometchat.") && name.contains("Call")
    }
}
