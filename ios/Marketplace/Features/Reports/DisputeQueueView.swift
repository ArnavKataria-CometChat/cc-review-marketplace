import SwiftUI

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
                        NavigationLink(value: report) {
                            ReportRow(report: report)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Disputes")
            .navigationDestination(for: Report.self) { report in
                ReportDetailView(reportId: report.id) { Task { await load() } }
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
