import SwiftUI

/// Gate in front of a CometChat conversation: shows a connecting/blocked state
/// until `ChatService` has logged the user into CometChat, then hands off to
/// `ChatConversationView`. Pushed onto a `NavigationStack` (never presented as a
/// sheet — see `ChatConversationView` / gotcha I3).
struct ChatScreen: View {
    let target: ChatTarget
    let title: String

    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var chat: ChatService

    var body: some View {
        Group {
            switch chat.phase {
            case .ready:
                ChatConversationView(target: target)
                    .ignoresSafeArea(.keyboard)
            case .failed(let message):
                EmptyState(title: "Chat unavailable",
                           systemImage: "bubble.left.and.exclamationmark.bubble.right",
                           description: message)
            case .idle, .connecting:
                ProgressView("Connecting to chat…")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        // Fallback: if the app-wide connect (MainTabView) hasn't run yet, start it.
        // connect() is fire-and-forget + idempotent and owns its own Task.
        .task {
            if case .idle = chat.phase {
                chat.connect(using: session.api)
            }
        }
    }
}
