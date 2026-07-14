import SwiftUI
import CometChatUIKitSwift
import CometChatSDK

/// The Chat tab: the CometChat conversation list. Tapping a conversation pushes
/// the full thread (`ChatScreen`) — a 1:1 buyer↔seller thread or the dispute
/// GROUP (buyer+seller+support). Every role reaches the same list: buyers/sellers
/// see their 1:1 threads; support sees the dispute groups it mediates. Calling
/// (voice + video, 1:1 or group) starts from the conversation header.
struct ConversationsScreen: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var chat: ChatService
    @State private var target: ChatTarget?

    var body: some View {
        NavigationStack {
            Group {
                switch chat.phase {
                case .ready:
                    ConversationsList(onSelect: { target = $0 })
                        .ignoresSafeArea(.keyboard)
                case .failed(let message):
                    EmptyState(title: "Chat unavailable",
                               systemImage: "bubble.left.and.exclamationmark.bubble.right",
                               description: message)
                case .idle, .connecting:
                    ProgressView("Connecting to chat…")
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            // Value-based push (stable) — the pushed ChatScreen survives the list
            // reloading; a group thread is reachable directly here (no fragile
            // report → group navigation).
            .navigationDestination(item: $target) { t in
                ChatScreen(target: t, title: "Chat")
            }
        }
        .task {
            if case .idle = chat.phase { await chat.connect(using: session.api) }
        }
    }
}

/// Hosts the kit's `CometChatConversations` list controller and surfaces taps as
/// a resolved `ChatTarget` (1:1 user or dispute group).
private struct ConversationsList: UIViewControllerRepresentable {
    let onSelect: (ChatTarget) -> Void

    func makeUIViewController(context: Context) -> CometChatConversations {
        let list = CometChatConversations()
        _ = list.set(onItemClick: { conversation, _ in
            switch conversation.conversationWith {
            case let user as CometChatSDK.User:
                onSelect(.user(uid: user.uid ?? ""))
            case let group as CometChatSDK.Group:
                onSelect(.group(guid: group.guid))
            default:
                break
            }
        })
        return list
    }

    func updateUIViewController(_ controller: CometChatConversations, context: Context) {}
}
