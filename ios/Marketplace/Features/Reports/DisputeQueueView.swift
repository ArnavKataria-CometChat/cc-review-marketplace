import SwiftUI

/// [I8] Stable navigation key for a report. Navigating by the whole `Report`
/// VALUE popped the pushed detail (and any dispute-group chat on top of it) the
/// moment the report's data changed — flagging or a background `load()` replaces
/// the Report value, so `navigationDestination(for: Report.self)` lost its key.
/// Keying on the immutable report id survives those reloads.
struct ReportRoute: Hashable {
    let id: String
}

/// [I8] Stable route for the dispute-group chat. Registered as a
/// `navigationDestination` at the STACK level (not inline in the reloading report
/// detail) and pushed by a VALUE-based NavigationLink — so once pushed it lives on
/// the stack and does not pop when the report detail's Form rebuilds.
struct GroupChatRoute: Hashable {
    let guid: String
}

/// Support/admin dispute queue. Filter by status; tap through for full context.
struct DisputeQueueView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var state: Loadable<[Report]> = .idle
    @State private var filter: ReportStatus? = nil

    var body: some View {
        NavigationStack {
            LoadableView(state: state, retry: { Task { await load() } }) { reports in
                if reports.isEmpty {
                    EmptyState(title: "Queue is clear",
                               systemImage: "checkmark.circle",
                               description: "No reports match this filter.")
                } else {
                    List(reports) { report in
                        NavigationLink(value: ReportRoute(id: report.id)) {
                            ReportRow(report: report)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Disputes")
            .navigationDestination(for: ReportRoute.self) { route in
                ReportDetailView(reportId: route.id) { Task { await load() } }
            }
            .navigationDestination(for: GroupChatRoute.self) { route in
                ChatScreen(target: .group(guid: route.guid), title: "Dispute")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Status", selection: $filter) {
                            Text("All").tag(ReportStatus?.none)
                            Text("Open").tag(ReportStatus?.some(.open))
                            Text("Flagged").tag(ReportStatus?.some(.flagged))
                            Text("Resolved").tag(ReportStatus?.some(.resolved))
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .refreshable { await load() }
            .onChange(of: filter) { Task { await load() } }
        }
        .task { if case .idle = state { await load() } }
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            state = .loaded(try await session.api.reports(status: filter))
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

struct ReportRow: View {
    let report: Report
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(report.targetType.rawValue.capitalized,
                      systemImage: icon(for: report.targetType))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusPill(text: report.status.label, color: report.status.pillColor)
            }
            Text(report.reason)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if report.inquiryId != nil {
                Label("Linked to an inquiry thread", systemImage: "link")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }

    private func icon(for type: ReportTargetType) -> String {
        switch type {
        case .listing: return "tag"
        case .user: return "person"
        case .message: return "bubble.left"
        }
    }
}
