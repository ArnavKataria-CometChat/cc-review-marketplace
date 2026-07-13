import SwiftUI

/// Top-level router. Chooses the login screen or a role-scoped tab layout.
/// Each tab set is the *only* surface that role can reach — the UI RBAC mirror
/// of the backend's route guards.
struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        switch session.phase {
        case .loading:
            ProgressView("Loading…")
        case .signedOut:
            LoginView()
        case .signedIn:
            if let user = session.currentUser {
                MainTabView(user: user)
            } else {
                ProgressView()
            }
        }
    }
}

struct MainTabView: View {
    let user: User
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        TabView {
            switch user.role {
            case .buyer:
                BrowseView()
                    .tabItem { Label("Browse", systemImage: "magnifyingglass") }
                FavoritesView()
                    .tabItem { Label("Favorites", systemImage: "heart") }
                InquiriesView()
                    .tabItem { Label("Inquiries", systemImage: "bubble.left.and.bubble.right") }

            case .seller:
                MyListingsView()
                    .tabItem { Label("My Listings", systemImage: "tag") }
                InquiriesView()
                    .tabItem { Label("Inbox", systemImage: "tray.full") }
                BrowseView()
                    .tabItem { Label("Browse", systemImage: "magnifyingglass") }

            case .support:
                DisputeQueueView()
                    .tabItem { Label("Disputes", systemImage: "exclamationmark.bubble") }

            case .admin:
                AdminUsersView()
                    .tabItem { Label("Users", systemImage: "person.2") }
                AdminListingsView()
                    .tabItem { Label("Listings", systemImage: "tag") }
                DisputeQueueView()
                    .tabItem { Label("Disputes", systemImage: "exclamationmark.bubble") }
                AuditLogView()
                    .tabItem { Label("Audit", systemImage: "list.bullet.clipboard") }

            case .unknown:
                EmptyState(title: "Unsupported role",
                           systemImage: "questionmark.circle",
                           description: "Your account role isn't recognized by this app.")
            }

            AccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
    }
}
