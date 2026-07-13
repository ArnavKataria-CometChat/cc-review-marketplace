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

    // MARK: - Connect / disconnect

    /// Bring up CometChat for `api`'s authenticated user: fetch a token, init the
    /// SDKs once, then log in. Safe to call repeatedly — it no-ops when already
    /// connected as the same user and re-logs-in when the app user changed.
    func connect(using api: APIClient) async {
        if case .connecting = phase { return }

        do {
            let token = try await api.cometChatToken()

            // Already connected as this exact user — nothing to do.
            if phase == .ready, connectedUID == token.uid,
               CometChatUIKit.getLoggedInUser()?.uid == token.uid {
                return
            }

            phase = .connecting
            try await initializeSDKIfNeeded(appID: token.appId, region: token.region)

            // A different user is still logged in (account switch) — clear them first.
            if let existing = CometChatUIKit.getLoggedInUser(), existing.uid != token.uid {
                await logoutCometChat(existing)
            }

            if CometChatUIKit.getLoggedInUser()?.uid != token.uid {
                try await login(authToken: token.authToken)
            }

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

    func ccCallEnded(call: Call) { dismissOngoingCall() }
    func ccCallRejected(call: Call) { dismissOngoingCall() }

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
