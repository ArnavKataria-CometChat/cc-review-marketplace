import SwiftUI

struct AuditLogView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var state: Loadable<[AuditEntry]> = .idle

    var body: some View {
        NavigationStack {
            LoadableView(state: state, retry: { Task { await load() } }) { entries in
                if entries.isEmpty {
                    EmptyState(title: "No audit entries",
                               systemImage: "list.bullet.clipboard",
                               description: "Privileged actions will be logged here.")
                } else {
                    List(entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.action).font(.subheadline.weight(.semibold))
                                Spacer()
                                RoleBadge(role: entry.actorRole)
                            }
                            if !entry.details.isEmpty {
                                Text(entry.details).font(.footnote).foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("target: \(entry.target)")
                                    .font(.caption2).foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                Spacer()
                                Text(Format.dateTime(entry.createdAt))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Audit Log")
            .refreshable { await load() }
        }
        .task { if case .idle = state { await load() } }
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            state = .loaded(try await session.api.adminAudit())
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
