import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var state: Loadable<[FavoriteEntry]> = .idle

    var body: some View {
        NavigationStack {
            LoadableView(state: state, retry: { Task { await load() } }) { entries in
                if entries.isEmpty {
                    EmptyState(title: "No favorites yet",
                               systemImage: "heart",
                               description: "Save listings while browsing to find them here.")
                } else {
                    List {
                        ForEach(entries) { entry in
                            if let listing = entry.listing {
                                NavigationLink(value: listing) {
                                    ListingRow(listing: listing)
                                }
                            } else {
                                Text("Listing unavailable").foregroundStyle(.secondary)
                            }
                        }
                        .onDelete(perform: remove)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favorites")
            .navigationDestination(for: Listing.self) { ListingDetailView(listingId: $0.id) }
            .refreshable { await load() }
        }
        .task { if case .idle = state { await load() } }
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            state = .loaded(try await session.api.favorites())
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func remove(at offsets: IndexSet) {
        guard case .loaded(var entries) = state else { return }
        let toRemove = offsets.map { entries[$0] }
        entries.remove(atOffsets: offsets)
        state = .loaded(entries)
        Task {
            for entry in toRemove {
                try? await session.api.removeFavorite(listingId: entry.listingId)
            }
        }
    }
}
