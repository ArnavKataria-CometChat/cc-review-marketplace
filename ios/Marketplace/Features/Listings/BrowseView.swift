import SwiftUI

/// Buyer/seller browse + search. Public listings endpoint, filtered by search
/// text, category and a max price.
struct BrowseView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var state: Loadable<[Listing]> = .idle
    @State private var searchText = ""
    @State private var category: String = ""
    @State private var maxPriceDollars = ""

    var body: some View {
        NavigationStack {
            LoadableView(state: state, retry: { Task { await load() } }) { listings in
                if listings.isEmpty {
                    EmptyState(title: "No listings found",
                               systemImage: "magnifyingglass",
                               description: "Try a different search or category.")
                } else {
                    List(listings) { listing in
                        NavigationLink(value: listing) {
                            ListingRow(listing: listing)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Browse")
            .navigationDestination(for: Listing.self) { ListingDetailView(listingId: $0.id) }
            .searchable(text: $searchText, prompt: "Search listings")
            .onSubmit(of: .search) { Task { await load() } }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Category", selection: $category) {
                            Text("All categories").tag("")
                            ForEach(Categories.all, id: \.self) { c in
                                Text(c.capitalized).tag(c)
                            }
                        }
                        Divider()
                        Button("Clear filters") {
                            category = ""; maxPriceDollars = ""; searchText = ""
                            Task { await load() }
                        }
                    } label: {
                        Label("Filter", systemImage: category.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .onChange(of: category) { Task { await load() } }
        }
        .task { if case .idle = state { await load() } }
    }

    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            let maxCents = Int(maxPriceDollars).map { $0 * 100 }
            let listings = try await session.api.listings(
                search: searchText, category: category.isEmpty ? nil : category,
                maxPrice: maxCents)
            state = .loaded(listings)
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
