import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                if let user = session.currentUser {
                    Section {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name).font(.headline)
                                Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                                RoleBadge(role: user.role)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Account") {
                        LabeledContent("User ID", value: user.id)
                            .font(.footnote)
                            .textSelection(.enabled)
                        LabeledContent("Role", value: user.role.label)
                        LabeledContent("Member since", value: Format.date(user.createdAt))
                    }

                    Section {
                        Text(capabilities(for: user.role))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("What you can do")
                    }
                }

                Section("Server") {
                    LabeledContent("Backend", value: AppConfig.baseURL.absoluteString)
                        .font(.footnote)
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        showLogoutConfirm = true
                    }
                }
            }
            .navigationTitle("Account")
            .confirmationDialog("Sign out of Marketplace?",
                                isPresented: $showLogoutConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { session.logout() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func capabilities(for role: Role) -> String {
        switch role {
        case .buyer:
            return "Browse and search listings, save favorites, and open inquiries with sellers."
        case .seller:
            return "Create and manage listings, respond to inquiries, and mark items sold."
        case .support:
            return "Review the dispute queue and flagged-thread context, and advance or resolve reports."
        case .admin:
            return "Moderate users and listings, remove content, and review the audit log."
        case .unknown:
            return "No capabilities are available for this role."
        }
    }
}
