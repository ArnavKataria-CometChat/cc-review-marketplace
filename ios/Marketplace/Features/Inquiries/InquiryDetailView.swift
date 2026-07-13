import SwiftUI

/// The buyer↔seller thread anchor. Phase A shows the thread's context and lets a
/// participant close/reopen it or open a dispute. Phase B attaches CometChat 1:1
/// chat + a voice-call button here, keyed on this inquiry.
struct InquiryDetailView: View {
    let inquiry: Inquiry

    @EnvironmentObject private var session: SessionStore
    @State private var current: Inquiry
    @State private var listing: Listing?
    @State private var busy = false
    @State private var actionError: String?
    @State private var showReport = false

    init(inquiry: Inquiry) {
        self.inquiry = inquiry
        _current = State(initialValue: inquiry)
    }

    private var isParticipant: Bool {
        guard let uid = session.currentUser?.id else { return false }
        return uid == current.buyerId || uid == current.sellerId
    }

    var body: some View {
        Form {
            Section("Listing") {
                if let listing {
                    NavigationLink(value: listing) {
                        ListingRow(listing: listing)
                    }
                } else {
                    HStack { Text("Loading listing…"); Spacer(); ProgressView() }
                }
            }

            Section("Thread") {
                LabeledContent("Status") {
                    StatusPill(text: current.status.label, color: current.status.pillColor)
                }
                if current.flagged {
                    Label("This thread is under dispute review by support.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
                if !current.message.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Opening message").font(.caption).foregroundStyle(.secondary)
                        Text(current.message)
                    }
                }
                LabeledContent("Opened", value: Format.dateTime(current.createdAt))
            }

            // Phase B seam — chat + voice call live here, anchored to this inquiry.
            Section("Messaging") {
                Label("Direct messaging and voice calls with the other party arrive in a future update.",
                      systemImage: "bubble.left.and.bubble.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let actionError {
                Section { InlineError(message: actionError) }
            }

            if isParticipant {
                Section {
                    if current.status == .open {
                        Button("Close inquiry") { Task { await setStatus(.closed) } }
                            .disabled(busy)
                    } else {
                        Button("Reopen inquiry") { Task { await setStatus(.open) } }
                            .disabled(busy)
                    }
                    Button("Open a dispute", role: .destructive) { showReport = true }
                        .disabled(busy)
                }
            }
        }
        .navigationTitle("Inquiry")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Listing.self) { ListingDetailView(listingId: $0.id) }
        .sheet(isPresented: $showReport) {
            ReportSheet(targetType: .listing, targetId: current.listingId,
                        inquiryId: current.id, title: "Open a dispute")
        }
        .task { await loadListing() }
    }

    private func loadListing() async {
        listing = try? await session.api.listing(id: current.listingId)
    }

    private func setStatus(_ status: InquiryStatus) async {
        actionError = nil
        busy = true
        do {
            current = try await session.api.patchInquiry(id: current.id, status: status)
        } catch {
            actionError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        busy = false
    }
}
