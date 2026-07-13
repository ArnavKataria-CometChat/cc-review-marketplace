import SwiftUI

@main
struct MarketplaceApp: App {
    @StateObject private var session = SessionStore()

    // Shared CometChat manager. Injected as a plain environment object — NOT a
    // @StateObject — because it's a singleton and letting SwiftUI own its
    // lifecycle would re-init the SDK in a loop (gotcha I1).
    private let chat = ChatService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(chat)
                .task { await session.restore() }
        }
    }
}
