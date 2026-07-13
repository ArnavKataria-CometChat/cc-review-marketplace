import SwiftUI

struct AdminUsersView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var state: Loadable<[User]> = .idle

    var body: some View {
        NavigationStack {
            LoadableView(state: state, retry: { Task { await load() } }) { users in
                List(users) { user in
                    NavigationLink(value: user) { UserRow(user: user) }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Users")
            .navigationDestination(for: User.self) { user in
                AdminUserDetailView(user: user) { Task { await load() } }
            }
            .refreshable { await load() }
        }
        .task { if case .idle = state { await load() } }
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            state = .loaded(try await session.api.adminUsers())
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

struct AdminUserDetailView: View {
    let user: User
    var onChange: () -> Void

    @EnvironmentObject private var session: SessionStore
    @State private var current: User
    @State private var selectedRole: Role
    @State private var busy = false
    @State private var actionError: String?

    init(user: User, onChange: @escaping () -> Void) {
        self.user = user
        self.onChange = onChange
        _current = State(initialValue: user)
        _selectedRole = State(initialValue: user.role)
    }

    private var isSelf: Bool { session.currentUser?.id == current.id }

    var body: some View {
        Form {
            Section {
                UserRow(user: current)
                LabeledContent("User ID", value: current.id)
                    .font(.footnote).textSelection(.enabled)
                LabeledContent("Joined", value: Format.date(current.createdAt))
            }

            Section("Role") {
                Picker("Role", selection: $selectedRole) {
                    ForEach(Role.allCases.filter { $0 != .unknown }, id: \.self) { role in
                        Text(role.label).tag(role)
                    }
                }
                .disabled(isSelf)
                if selectedRole != current.role {
                    Button("Save role change") { Task { await changeRole() } }
                        .disabled(busy)
                }
            }

            if let actionError { Section { InlineError(message: actionError) } }

            Section("Moderation") {
                if isSelf {
                    Label("You can't ban your own account.", systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                } else if current.banned {
                    Button("Unban user") { Task { await setBanned(false) } }
                        .disabled(busy)
                } else {
                    Button("Ban user", role: .destructive) { Task { await setBanned(true) } }
                        .disabled(busy)
                }
            }
        }
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setBanned(_ banned: Bool) async {
        actionError = nil; busy = true
        do {
            current = try await session.api.adminPatchUser(id: current.id, banned: banned)
            onChange()
        } catch {
            actionError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        busy = false
    }

    private func changeRole() async {
        actionError = nil; busy = true
        do {
            current = try await session.api.adminPatchUser(id: current.id, role: selectedRole)
            onChange()
            if isSelf { await session.refreshMe() }
        } catch {
            actionError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        busy = false
    }
}
