import SwiftUI

/// Role-scoped inquiry list. The backend already scopes results:
/// buyer → own, seller → on their listings, admin → all, support → flagged.
struct InquiriesView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var state: Loadable<[Inquiry]> = .idle

    private var isSeller: Bool { session.role == .seller }

    var body: some View {
        NavigationStack {
            LoadableView(state: state, retry: { Task { await load() } }) { inquiries in
                if inquiries.isEmpty {
                    EmptyState(title: "No inquiries yet",
                               systemImage: "bubble.left.and.bubble.right",
                               description: emptyHint)
                } else {
                    List(inquiries) { inquiry in
                        NavigationLink(value: inquiry) {
                            InquiryRow(inquiry: inquiry, showBuyerAngle: !isSeller)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(isSeller ? "Inbox" : "Inquiries")
            .navigationDestination(for: Inquiry.self) { InquiryDetailView(inquiry: $0) }
            .refreshable { await load() }
        }
        .task { if case .idle = state { await load() } }
    }

    private var emptyHint: String {
        switch session.role {
        case .seller: return "Inquiries from buyers on your listings appear here."
        case .buyer: return "Contact a seller from a listing to start an inquiry."
        default: return "Nothing to show."
        }
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            state = .loaded(try await session.api.inquiries())
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

struct InquiryRow: View {
    let inquiry: Inquiry
    let showBuyerAngle: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(inquiry.message.isEmpty ? "Inquiry" : inquiry.message)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer()
            }
            HStack(spacing: 8) {
                StatusPill(text: inquiry.status.label, color: inquiry.status.pillColor)
                if inquiry.flagged {
                    StatusPill(text: "disputed", color: .red)
                }
                Spacer()
                Text(Format.date(inquiry.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
