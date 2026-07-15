import Foundation
import SwiftUI
import CometChatUIKitSwift
import CometChatSDK
import CometChatCallsSDK

/// Owns the CometChat session for the whole app: one-time SDK initialization,
/// token-based login, and the call-lifecycle glue the UI Kit doesn't handle
/// itself.
///
/// This is a **shared singleton** used through the environment as a plain
/// dependency. It is intentionally NOT created with `@StateObject` anywhere —
/// letting SwiftUI own a singleton's lifecycle re-inits it in a loop and
/// re-fires the CometChat init/login (gotcha I1). Inject `ChatService.shared`
/// with `.environmentObject(_:)` and drive startup from a one-shot `.task(id:)`.
///
/// Credentials model: the app ships **no** CometChat App ID / Region / keys.
/// Everything arrives at runtime from the backend's `POST /cometchat/token`
/// (App ID + Region + a short-lived per-user auth token). The REST API Key is
/// server-only and never reaches the client.
@MainActor
final class ChatService: ObservableObject {

    static let shared = ChatService()

    enum Phase: Equatable {
        case idle
        case connecting
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle

    /// The CometChat UID (== app user id) of the currently connected user.
    private(set) var connectedUID: String?

    private var didInitSDK = false
    private let callListener = CallCleanupListener()
    private let callListenerID = "marketplace.call.cleanup"

    private init() {}

    var isReady: Bool { phase == .ready }

    /// The connect work runs in a Task OWNED by this service, not the SwiftUI view
    /// that triggered it. Critical: the SDK init/login use
    /// withCheckedThrowingContinuation, which does NOT observe task cancellation —
    /// so if connect ran directly inside a view's `.task` and that view updated
    /// (cancelling the task) while suspended in a continuation, the continuation
    /// was ORPHANED: the await never returned, `phase` stuck at `.connecting`
    /// forever ("Connecting to chat…") and the message list never got a live
    /// session (perpetual skeletons). Owning the Task here keeps connect immune to
    /// view churn. Observed symptom before this: `POST /cometchat/token` cancelled.
    private var connectTask: Task<Void, Never>?

    // MARK: - Connect / disconnect

    /// Bring up CometChat for `api`'s authenticated user. Fire-and-forget +
    /// idempotent: no-ops when a connect is already running or we're already
    /// connected as the same user. Runs on a service-owned Task (see above).
    func connect(using api: APIClient) {
        if let task = connectTask, !task.isCancelled { return }  // already connecting
        if phase == .ready, let uid = connectedUID,
           CometChatUIKit.getLoggedInUser()?.uid == uid {
            return
        }
        connectTask = Task { [weak self] in
            await self?.performConnect(using: api)
            self?.connectTask = nil
        }
    }

    private func performConnect(using api: APIClient) async {
        phase = .connecting
        do {
            let token = try await api.cometChatToken()

            // Already connected as this exact user — nothing to do.
            if connectedUID == token.uid,
               CometChatUIKit.getLoggedInUser()?.uid == token.uid {
                phase = .ready
                return
            }

            try await initializeSDKIfNeeded(appID: token.appId, region: token.region)

            // A different user is still logged in (account switch) — clear them first.
            if let existing = CometChatUIKit.getLoggedInUser(), existing.uid != token.uid {
                await logoutCometChat(existing)
            }

            if CometChatUIKit.getLoggedInUser()?.uid != token.uid {
                try await login(authToken: token.authToken)
            }

            // [GHOST-SWEEP] End any STALE active call left over from a previous
            // session/crash — SERVER-SIDE too (clearActiveCall alone is client-
            // local). A hanging ghost reports this user BUSY: fresh rings
            // auto-reject and an accepted call is torn down instantly by the
            // ghost's late end-event. A fresh connect can never have a
            // legitimately-active call, so this is always safe here.
            // NOTE: do NOT call CometChat.connect() here — the UIKit login already
            // establishes the socket WITH the presence subscription; a second
            // explicit connect() re-established it WITHOUT presence, which broke
            // presence sync (peer showed "Offline") and call signalling.
            if let ghost = CometChat.getActiveCall(),
               let sid = ghost.sessionID, !sid.isEmpty {
                CometChat.endCall(sessionID: sid) { _ in } onError: { _ in }
            }
            CometChat.clearActiveCall()

            connectedUID = token.uid
            phase = .ready
        } catch let error as APIError {
            phase = .failed(error.errorDescription ?? "Chat is unavailable.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Tear down the CometChat session when the app user signs out.
    func disconnect() async {
        guard let user = CometChatUIKit.getLoggedInUser() else {
            phase = .idle
            connectedUID = nil
            return
        }
        await logoutCometChat(user)
        connectedUID = nil
        phase = .idle
    }

    // MARK: - SDK init (once)

    private func initializeSDKIfNeeded(appID: String, region: String) async throws {
        guard !didInitSDK else { return }

        // 1. Chat / UI Kit. `enable(inAppIncomingCall:)` lets the kit present its
        //    incoming- and ongoing-call UI on the key-window root by itself — which
        //    is why the chat conversation is *pushed* on a NavigationStack rather
        //    than shown as a modal (a modal would occupy the root's only
        //    presentation slot and an inbound call would be dropped, gotcha I3).
        let settings = UIKitSettings()
            .set(appID: appID)
            .set(region: region)
            .subscribePresenceForAllUsers()
            .enable(inAppIncomingCall: true)
            .build()

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            _ = CometChatUIKit(uiKitSettings: settings) { result in
                switch result {
                case .success: cont.resume()
                case .failure(let error): cont.resume(throwing: error)
                }
            }
        }

        // 2. Calls / WebRTC SDK. This is a SEPARATE SDK and is NOT initialized by
        //    the chat init — it must be initialized explicitly right after, or
        //    calls never leave the "connecting" state (gotcha X1).
        let callSettings = CallAppSettingsBuilder()
            .set(appID: appID)
            .set(region: region)
            .build()

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            _ = CometChatCalls(callsAppSettings: callSettings, onSuccess: { _ in
                cont.resume()
            }, onError: { error in
                // CometChatCallException does NOT conform to Swift.Error — wrap it.
                cont.resume(throwing: ChatSDKError(error?.errorDescription))
            })
        }

        // 3. The UI Kit's ongoing-call screen does NOT auto-dismiss when the REMOTE
        //    party ends a 1:1 call (it treats it as a conference), leaving a ghost
        //    call with the timer running. This listener dismisses it + clears the
        //    active call on ccCallEnded/ccCallRejected (gotcha I4).
        CometChatCallEvents.addListener(callListenerID, callListener)

        // 4. [I12] Release the call session SERVER-SIDE when the app terminates
        //    mid-call. clearActiveCall() is client-local only: an app killed
        //    during a call leaves the session ongoing server-side, wedging this
        //    user-pair BUSY (every subsequent call insta-rejects) until the
        //    zombie expires — the "connects sometimes, then doesn't" symptom.
        //    Best-effort: willTerminate can't cover a force-kill; the durable
        //    fix belongs in the SDK/skill (recorded as I12).
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { _ in
            if let active = CometChat.getActiveCall(),
               let sid = active.sessionID, !sid.isEmpty {
                CometChat.endCall(sessionID: sid) { _ in } onError: { _ in }
            }
        }

        didInitSDK = true
    }

    // MARK: - Login / logout wrappers

    private func login(authToken: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            CometChatUIKit.login(authToken: authToken) { result in
                switch result {
                case .success: cont.resume()
                // CometChatException does NOT conform to Swift.Error — wrap it.
                case .onError(let error): cont.resume(throwing: ChatSDKError(error.errorDescription))
                @unknown default: cont.resume(throwing: ChatSDKError(nil))
                }
            }
        }
    }

    private func logoutCometChat(_ user: CometChatSDK.User) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            CometChatUIKit.logout(user: user) { _ in cont.resume() }
        }
    }

    /// Wraps CometChat's `CometChatException` / `CometChatCallException` (neither
    /// of which conforms to Swift's `Error`) so they can flow through `throws`.
    struct ChatSDKError: LocalizedError {
        let message: String?
        init(_ message: String?) { self.message = message }
        var errorDescription: String? { message ?? "Could not start the chat service." }
    }
}

/// Dismisses the UI Kit's ongoing-call overlay when a 1:1 call ends remotely.
///
/// The ongoing-call screen lives on its own overlay window and runs in its own
/// task, so on a remote hang-up it is left on-screen with the timer running.
/// On `ccCallEnded` / `ccCallRejected` we scan every scene window (the call VC
/// may be a window's root OR presented on top of it), dismiss any
/// `CometChatOngoingCall`, and clear the SDK's active call (gotcha I4).
///
/// Kept as a plain (non-`@MainActor`) object so it can satisfy the SDK's
/// synchronous listener protocol; all work is hopped onto the main queue.
final class CallCleanupListener: CometChatCallEventListener {

    func ccCallEnded(call: Call) { dismissIfActive(call) }
    func ccCallRejected(call: Call) { dismissIfActive(call) }

    /// Only tear down when the ended/rejected call IS the currently-active one.
    /// End/reject events also arrive for OLD sessions (a busy-reject of a stale
    /// ring, a late end for a prior call); acting on those would dismiss + clear
    /// a DIFFERENT call that just started — killing a fresh call "as soon as it's
    /// initiated". If there's no active call, allow the dismiss (cleanup).
    private func dismissIfActive(_ call: Call) {
        if let active = CometChat.getActiveCall(),
           let ended = call.sessionID, !ended.isEmpty,
           ended != active.sessionID {
            return
        }
        dismissOngoingCall()
    }

    private func dismissOngoingCall() {
        DispatchQueue.main.async {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    // The ongoing-call VC may be presented on top of the root…
                    var controller = window.rootViewController
                    while let presented = controller?.presentedViewController {
                        if presented is CometChatOngoingCall {
                            presented.dismiss(animated: true)
                            break
                        }
                        controller = presented
                    }
                    // …or be the overlay window's own root.
                    if let root = window.rootViewController, root is CometChatOngoingCall {
                        root.dismiss(animated: true)
                    }
                }
            }
            CometChat.clearActiveCall()
        }
    }
}
