import Foundation
import SwiftUI

/// Owns authentication state for the whole app: the session token, the current
/// user, and the shared `APIClient`. Views read `currentUser`/`phase` and call
/// `login`/`logout`.
///
/// The token is persisted in `UserDefaults` to keep the baseline runnable; a
/// production app would store it in the Keychain. The server-side `user.id` and
/// `role` are stable and are the identity a Phase B CometChat integration maps
/// onto a CometChat user.
@MainActor
final class SessionStore: ObservableObject {

    enum Phase: Equatable {
        case loading        // restoring a persisted session
        case signedOut
        case signedIn
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var currentUser: User?

    let api: APIClient

    private let tokenKey = "session.token"

    init(api: APIClient = APIClient()) {
        self.api = api
        self.api.onUnauthorized = { [weak self] in
            self?.handleUnauthorized()
        }
    }

    var role: Role? { currentUser?.role }

    /// Restore a persisted session on launch, validating the token against the
    /// backend. Falls back to signed-out if anything fails.
    func restore() async {
        guard let saved = UserDefaults.standard.string(forKey: tokenKey), !saved.isEmpty else {
            phase = .signedOut
            return
        }
        api.token = saved
        do {
            let user = try await api.me()
            currentUser = user
            phase = .signedIn
        } catch {
            clearToken()
            phase = .signedOut
        }
    }

    func login(email: String, password: String) async throws {
        let resp = try await api.login(email: email, password: password)
        apply(resp)
    }

    func register(name: String, email: String, password: String, role: Role) async throws {
        let resp = try await api.register(name: name, email: email, password: password, role: role)
        apply(resp)
    }

    func logout() {
        clearToken()
        currentUser = nil
        phase = .signedOut
        Task { await ChatService.shared.disconnect() }
    }

    /// Refresh the cached user (e.g. after an admin role change to self).
    func refreshMe() async {
        guard phase == .signedIn else { return }
        if let user = try? await api.me() {
            currentUser = user
        }
    }

    // MARK: - Private

    private func apply(_ resp: AuthResponse) {
        UserDefaults.standard.set(resp.token, forKey: tokenKey)
        api.token = resp.token
        currentUser = resp.user
        phase = .signedIn
    }

    private func clearToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        api.token = nil
    }

    private func handleUnauthorized() {
        // Called when the backend rejects our token mid-session.
        clearToken()
        currentUser = nil
        phase = .signedOut
    }
}
