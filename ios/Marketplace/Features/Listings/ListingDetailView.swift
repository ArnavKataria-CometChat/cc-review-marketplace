import SwiftUI

struct ListingDetailView: View {
    let listingId: String

    @EnvironmentObject private var session: SessionStore
    @State private var state: Loadable<Listing> = .idle

    @State private var isFavorited = false
    @State private var favoriteBusy = false
    @State private var inquiryBusy = false
    @State private var openedInquiry: Inquiry?
    @State private var actionError: String?
    @State private var showReport = false
    @State private var navigateToInquiry = false

    private var user: User? { session.currentUser }

    var body: some View {
        LoadableView(state: state, retry: { Task { await load() } }) { listing in
            content(listing)
        }
        .navigationTitle("Listing")
        .navigationBarTitleDisplayMode(.inline)
        .task { if case .idle = state { await load() } }
        .sheet(isPresented: $showReport) {
            ReportSheet(targetType: .listing, targetId: listingId, title: "Report listing")
        }
    }

    @ViewBuilder
    private func content(_ listing: Listing) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                gallery(listing)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(listing.title).font(.title2.bold())
                        Spacer()
                        StatusPill(text: listing.status.label, color: listing.status.pillColor)
                    }
                    Text(Format.price(listing.priceCents))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(listing.category.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !listing.description.isEmpty {
                    Text(listing.description)
                        .font(.body)
                }

                if let actionError {
                    InlineError(message: actionError)
                }

                actions(listing)
            }
            .padding()
        }
        .navigationDestination(isPresented: $navigateToInquiry) {
            if let inq = openedInquiry {
                InquiryDetailView(inquiry: inq)
            }
        }
    }

    @ViewBuilder
    private func gallery(_ listing: Listing) -> some View {
        if listing.photos.isEmpty {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 180)
                .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.tertiary))
        } else {
            TabView {
                ForEach(listing.photos, id: \.self) { photo in
                    AsyncImage(url: URL(string: photo)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .clipped()
                }
            }
            .frame(height: 220)
            .tabViewStyle(.page)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // Role-scoped actions on a listing.
    @ViewBuilder
    private func actions(_ listing: Listing) -> some View {
        let isOwnListing = user?.id == listing.sellerId

        if user?.role == .buyer {
            VStack(spacing: 12) {
                Button {
                    Task { await contactSeller(listing) }
                } label: {
                    HStack {
                        if inquiryBusy { ProgressView() }
                        else { Label("Contact seller", systemImage: "bubble.left") }
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(inquiryBusy || listing.status != .active)

                Button {
                    Task { await toggleFavorite(listing) }
                } label: {
                    Label(isFavorited ? "Saved" : "Save to favorites",
                          systemImage: isFavorited ? "heart.fill" : "heart")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(favoriteBusy)
            }
        } else if isOwnListing {
            Label("This is your listing.", systemImage: "person.crop.circle.badge.checkmark")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        Button(role: .destructive) {
            showReport = true
        } label: {
            Label("Report listing", systemImage: "flag")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.top, 4)
    }

    // MARK: - Data

    private func load() async {
        state = .loading
        do {
            let listing = try await session.api.listing(id: listingId)
            state = .loaded(listing)
            if user?.role == .buyer { await refreshFavorite() }
        } catch {
            state = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func refreshFavorite() async {
        if let favs = try? await session.api.favorites() {
            isFavorited = favs.contains { $0.listingId == listingId }
        }
    }

    private func contactSeller(_ listing: Listing) async {
        actionError = nil
        inquiryBusy = true
        do {
            let inq = try await session.api.createInquiry(
                listingId: listing.id,
                message: "Hi, I'm interested in \"\(listing.title)\".")
            openedInquiry = inq
            navigateToInquiry = true
        } catch {
            actionError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        inquiryBusy = false
    }

    private func toggleFavorite(_ listing: Listing) async {
        actionError = nil
        favoriteBusy = true
        do {
            if isFavorited {
                try await session.api.removeFavorite(listingId: listing.id)
                isFavorited = false
            } else {
                try await session.api.addFavorite(listingId: listing.id)
                isFavorited = true
            }
        } catch {
            actionError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        favoriteBusy = false
    }
}
