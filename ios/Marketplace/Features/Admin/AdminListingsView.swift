import SwiftUI

/// Admin listings moderation. Shows all active listings; admin can remove any
/// (status → removed), which is also the Phase B hook for purging associated
/// conversations.
struct AdminListingsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var state: Loadable<[Listing]> = .idle

    var body: some View {
        NavigationStack {
            LoadableView(state: state, retry: { Task { await load() } }) { listings in
                if listings.isEmpty {
                    EmptyState(title: "No listings", systemImage: "tag")
                } else {
                    List(listings) { listing in
                        NavigationLink(value: listing) { ListingRow(listing: listing) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Listings")
            .navigationDestination(for: Listing.self) { listing in
                AdminListingDetailView(listing: listing) { Task { await load() } }
            }
            .refreshable { await load() }
        }
        .task { if case .idle = state { await load() } }
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            state = .loaded(try await session.api.listings())
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

struct AdminListingDetailView: View {
    let listing: Listing
    var onChange: () -> Void

    @EnvironmentObject private var session: SessionStore
    @State private var current: Listing
    @State private var busy = false
    @State private var actionError: String?
    @State private var showRemoveConfirm = false

    init(listing: Listing, onChange: @escaping () -> Void) {
        self.listing = listing
        self.onChange = onChange
        _current = State(initialValue: listing)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Title", value: current.title)
                LabeledContent("Price", value: Format.price(current.priceCents))
                LabeledContent("Category", value: current.category.capitalized)
                LabeledContent("Seller ID", value: current.sellerId)
                    .font(.footnote).textSelection(.enabled)
                LabeledContent("Status") {
                    StatusPill(text: current.status.label, color: current.status.pillColor)
                }
            }
            if !current.description.isEmpty {
                Section("Description") { Text(current.description) }
            }

            if let actionError { Section { InlineError(message: actionError) } }

            Section {
                if current.status == .removed {
                    Label("This listing has been removed.", systemImage: "checkmark.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Button("Remove listing", role: .destructive) { showRemoveConfirm = true }
                        .disabled(busy)
                }
            } footer: {
                Text("Removing a listing hides it from buyers. In Phase B this also purges any conversations tied to the listing.")
            }
        }
        .navigationTitle(current.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Remove this listing?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { Task { await remove() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func remove() async {
        actionError = nil; busy = true
        do {
            current = try await session.api.adminRemoveListing(id: current.id)
            onChange()
        } catch {
            actionError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        busy = false
    }
}
