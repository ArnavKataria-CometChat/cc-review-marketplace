import Foundation

// MARK: - Enums
//
// These mirror the backend enums exactly (see ../backend/internal/models).
// Unknown/forward-compatible values decode to `.unknown` rather than throwing so
// a new server-side status never crashes the client.

enum Role: String, Codable, CaseIterable, Hashable {
    case buyer, seller, support, admin
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Role(rawValue: raw) ?? .unknown
    }

    var label: String {
        switch self {
        case .buyer: return "Buyer"
        case .seller: return "Seller"
        case .support: return "Support"
        case .admin: return "Admin"
        case .unknown: return "Unknown"
        }
    }
}

enum ListingStatus: String, Codable, Hashable {
    case active, sold, removed
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ListingStatus(rawValue: raw) ?? .unknown
    }
}

enum InquiryStatus: String, Codable, Hashable {
    case open, closed
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = InquiryStatus(rawValue: raw) ?? .unknown
    }
}

enum ReportTargetType: String, Codable, Hashable {
    case listing, user, message
}

enum ReportStatus: String, Codable, Hashable {
    case open, flagged, resolved
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ReportStatus(rawValue: raw) ?? .unknown
    }
}

// MARK: - Entities

struct User: Codable, Identifiable, Hashable {
    let id: String
    let role: Role
    let name: String
    let email: String
    var banned: Bool
    let createdAt: Date?

    // `banned` is omitted from some payloads (defaults false); createdAt is
    // optional because a few embedded contexts may not carry it.
    enum CodingKeys: String, CodingKey {
        case id, role, name, email, banned, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        role = try c.decode(Role.self, forKey: .role)
        name = try c.decode(String.self, forKey: .name)
        email = try c.decode(String.self, forKey: .email)
        banned = try c.decodeIfPresent(Bool.self, forKey: .banned) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }
}

struct Listing: Codable, Identifiable, Hashable {
    let id: String
    let sellerId: String
    var title: String
    var description: String
    var priceCents: Int
    var category: String
    var status: ListingStatus
    var photos: [String]
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, sellerId, title, description, priceCents, category, status, photos, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        sellerId = try c.decode(String.self, forKey: .sellerId)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        priceCents = try c.decode(Int.self, forKey: .priceCents)
        category = try c.decode(String.self, forKey: .category)
        status = try c.decode(ListingStatus.self, forKey: .status)
        photos = try c.decodeIfPresent([String].self, forKey: .photos) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct Inquiry: Codable, Identifiable, Hashable {
    let id: String
    let listingId: String
    let buyerId: String
    let sellerId: String
    var status: InquiryStatus
    var message: String
    var flagged: Bool
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, listingId, buyerId, sellerId, status, message, flagged, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        listingId = try c.decode(String.self, forKey: .listingId)
        buyerId = try c.decode(String.self, forKey: .buyerId)
        sellerId = try c.decode(String.self, forKey: .sellerId)
        status = try c.decode(InquiryStatus.self, forKey: .status)
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        flagged = try c.decodeIfPresent(Bool.self, forKey: .flagged) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct Favorite: Codable, Hashable {
    let userId: String
    let listingId: String
    let createdAt: Date?
}

// A favorites list entry inlines the listing (see GET /favorites).
struct FavoriteEntry: Codable, Identifiable, Hashable {
    let userId: String
    let listingId: String
    let createdAt: Date?
    let listing: Listing?

    var id: String { listingId }
}

struct Report: Codable, Identifiable, Hashable {
    let id: String
    let targetType: ReportTargetType
    let targetId: String
    let reporterId: String
    let reason: String
    var status: ReportStatus
    let inquiryId: String?
    let createdAt: Date?
    let updatedAt: Date?
}

// GET /reports/:id returns the report plus the context support needs.
struct ReportDetail: Codable {
    let report: Report
    let reporter: User?
    let listing: Listing?
    let inquiry: Inquiry?
    let buyer: User?
    let seller: User?
}

struct AuditEntry: Codable, Identifiable, Hashable {
    let id: String
    let actorId: String
    let actorRole: Role
    let action: String
    let target: String
    let details: String
    let createdAt: Date?
}

// MARK: - Auth + response envelopes

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct ListingsEnvelope: Codable { let listings: [Listing] }
struct InquiriesEnvelope: Codable { let inquiries: [Inquiry] }
struct FavoritesEnvelope: Codable { let favorites: [FavoriteEntry] }
struct ReportsEnvelope: Codable { let reports: [Report] }
struct UsersEnvelope: Codable { let users: [User] }
struct AuditEnvelope: Codable { let audit: [AuditEntry] }
