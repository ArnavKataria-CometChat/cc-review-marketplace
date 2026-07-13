import SwiftUI

/// Seller's own listings. The backend has no "my listings" endpoint, so we fetch
/// all active listings and filter to the seller's id; removed/sold ones the
/// seller edited stay visible via detail. Create + mark-sold live here.
struct MyListingsView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var state: Loadable<[Listing]> = .idle
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            LoadableView(state: state, retry: { Task { await load() } }) { listings in
                if listings.isEmpty {
                    EmptyState(title: "No listings yet",
                               systemImage: "tag",
                               description: "Tap + to create your first listing.")
                } else {
                    List(listings) { listing in
                        NavigationLink(value: listing) {
                            ListingRow(listing: listing)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Listings")
            .navigationDestination(for: Listing.self) { listing in
                SellerListingDetailView(listing: listing) { Task { await load() } }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreate = true } label: { Image(systemName: "plus") }
                }
            }
            .refreshable { await load() }
            .sheet(isPresented: $showCreate) {
                CreateListingView { Task { await load() } }
            }
        }
        .task { if case .idle = state { await load() } }
    }

    private func load() async {
        guard let uid = session.currentUser?.id else { return }
        if case .loaded = state {} else { state = .loading }
        do {
            let all = try await session.api.listings()
            state = .loaded(all.filter { $0.sellerId == uid })
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}

/// Seller-facing detail with edit/mark-sold actions on their own listing.
struct SellerListingDetailView: View {
    let listing: Listing
    var onChange: () -> Void

    @EnvironmentObject private var session: SessionStore
    @State private var current: Listing
    @State private var busy = false
    @State private var actionError: String?

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
                LabeledContent("Status") {
                    StatusPill(text: current.status.label, color: current.status.pillColor)
                }
            }
            if !current.description.isEmpty {
                Section("Description") { Text(current.description) }
            }

            if let actionError { Section { InlineError(message: actionError) } }

            if current.status == .active {
                Section {
                    Button("Mark as sold") { Task { await update(status: .sold) } }
                        .disabled(busy)
                }
            } else if current.status == .sold {
                Section {
                    Button("Relist (mark active)") { Task { await update(status: .active) } }
                        .disabled(busy)
                }
            } else if current.status == .removed {
                Section {
                    Label("This listing was removed by a moderator.",
                          systemImage: "exclamationmark.octagon")
                        .foregroundStyle(.red).font(.footnote)
                }
            }
        }
        .navigationTitle(current.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func update(status: ListingStatus) async {
        actionError = nil
        busy = true
        do {
            current = try await session.api.patchListing(id: current.id, patch: ListingPatch(status: status))
            onChange()
        } catch {
            actionError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        busy = false
    }
}
