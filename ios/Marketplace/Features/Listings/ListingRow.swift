import SwiftUI

/// Compact listing cell used in browse/favorites/seller lists.
struct ListingRow: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(listing.category.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(Format.price(listing.priceCents))
                        .font(.subheadline.weight(.semibold))
                    if listing.status != .active {
                        StatusPill(text: listing.status.label, color: listing.status.pillColor)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var thumbnail: some View {
        let size: CGFloat = 56
        if let first = listing.photos.first, let url = URL(string: first) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            placeholder.frame(width: size, height: size)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(.secondarySystemBackground))
            .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
    }
}
