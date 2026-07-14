import SwiftUI

/// Full report context for support/admin: the report, reporter, disputed listing
/// and — when linked — the inquiry thread with both parties. Support advances the
/// report through open → flagged → resolved. Flagging a thread-linked report
/// escalates the inquiry into a dispute (Phase B: a buyer+seller+support group).
struct ReportDetailView: View {
    let reportId: String
    var onChange: () -> Void

    @EnvironmentObject private var session: SessionStore
    @State private var state: Loadable<ReportDetail> = .idle
    @State private var busy = false
    @State private var actionError: String?

    var body: some View {
        LoadableView(state: state, retry: { Task { await load() } }) { detail in
            content(detail)
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .task { if case .idle = state { await load() } }
    }

    @ViewBuilder
    private func content(_ detail: ReportDetail) -> some View {
        Form {
            Section("Report") {
                LabeledContent("Status") {
                    StatusPill(text: detail.report.status.label, color: detail.report.status.pillColor)
                }
                LabeledContent("Target", value: detail.report.targetType.rawValue.capitalized)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reason").font(.caption).foregroundStyle(.secondary)
                    Text(detail.report.reason)
                }
                LabeledContent("Filed", value: Format.dateTime(detail.report.createdAt))
            }

            if let reporter = detail.reporter {
                Section("Reporter") { UserRow(user: reporter) }
            }

            if let listing = detail.listing {
                Section("Disputed listing") {
                    ListingRow(listing: listing)
                    LabeledContent("Price", value: Format.price(listing.priceCents))
                    LabeledContent("Status", value: listing.status.label.capitalized)
                }
            }

            if let inquiry = detail.inquiry {
                Section("Inquiry thread") {
                    if inquiry.flagged {
                        Label("Escalated to a dispute.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.footnote)
                    }
                    if !inquiry.message.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Opening message").font(.caption).foregroundStyle(.secondary)
                            Text(inquiry.message)
                        }
                    }
                    LabeledContent("Thread status", value: inquiry.status.label.capitalized)
                }
                Section("Parties") {
                    if let buyer = detail.buyer { UserRow(user: buyer) }
                    if let seller = detail.seller { UserRow(user: seller) }
                }
                // Phase B — the dispute group. Once the report is flagged the
                // backend provisions a buyer+seller+support CometChat group
                // (GUID `dispute-<inquiryId>`); support mediates inside it with
                // group chat + group voice/video call.
                Section("Dispute group") {
                    if inquiry.flagged {
                        // [I8] VALUE-based push (destination registered on the
                        // stack in DisputeQueueView) — survives the Form reloads
                        // that popped the old inline NavigationLink.
                        NavigationLink(value: GroupChatRoute(guid: "dispute-\(inquiry.id)")) {
                            Label("Open group chat & call", systemImage: "person.3.fill")
                        }
                        Text("Group conversation with the buyer and seller. Voice & video call buttons are in the chat header.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Label("Flag this report to escalate it into a buyer + seller + support group.",
                              systemImage: "person.3")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }

            if let actionError { Section { InlineError(message: actionError) } }

            Section("Actions") {
                actionButtons(detail.report)
            }
        }
    }

    @ViewBuilder
    private func actionButtons(_ report: Report) -> some View {
        if report.status != .flagged {
            Button {
                Task { await advance(to: .flagged) }
            } label: {
                Label("Flag / escalate to dispute", systemImage: "flag.fill")
            }
            .disabled(busy)
        }
        if report.status != .resolved {
            Button {
                Task { await advance(to: .resolved) }
            } label: {
                Label("Resolve", systemImage: "checkmark.seal.fill")
            }
            .disabled(busy)
        }
        if report.status != .open {
            Button {
                Task { await advance(to: .open) }
            } label: {
                Label("Reopen", systemImage: "arrow.uturn.backward")
            }
            .disabled(busy)
        }
    }

    private func load() async {
        state = .loading
        do {
            state = .loaded(try await session.api.report(id: reportId))
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func advance(to status: ReportStatus) async {
        actionError = nil
        busy = true
        do {
            _ = try await session.api.patchReport(id: reportId, status: status)
            onChange()
            await load()
        } catch {
            actionError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        busy = false
    }
}

/// Small user summary row reused in report context and admin lists.
struct UserRow: View {
    let user: User
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.subheadline.weight(.medium))
                Text(user.email).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if user.banned {
                StatusPill(text: "banned", color: .red)
            }
            RoleBadge(role: user.role)
        }
    }
}
