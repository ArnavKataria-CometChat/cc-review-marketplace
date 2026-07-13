import Foundation

/// Thin async HTTP client for the marketplace backend. One instance is shared
/// through the environment; `SessionStore` keeps `token` in sync.
final class APIClient: @unchecked Sendable {
    private let session: URLSession
    private let baseURL: URL

    /// Bearer token for authenticated requests. Set by `SessionStore`.
    private let lock = NSLock()
    private var _token: String?
    var token: String? {
        get { lock.lock(); defer { lock.unlock() }; return _token }
        set { lock.lock(); _token = newValue; lock.unlock() }
    }

    /// Invoked (on the main actor) when the server rejects the token (401), so
    /// the app can force a sign-out.
    var onUnauthorized: (@MainActor @Sendable () -> Void)?

    init(baseURL: URL = AppConfig.baseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    private enum Method: String { case GET, POST, PATCH, DELETE }

    // MARK: - Core request

    private func request<T: Decodable>(
        _ method: Method,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        authenticated: Bool = true,
        decode: T.Type = T.self
    ) async throws -> T {
        let data = try await requestData(method, path, query: query, body: body, authenticated: authenticated)
        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }
        do {
            return try APICoding.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    @discardableResult
    private func requestData(
        _ method: Method,
        _ path: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> Data {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if authenticated, let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                req.httpBody = try APICoding.encoder.encode(AnyEncodable(body))
            } catch {
                throw APIError.decoding("could not encode request")
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("invalid response")
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            if let cb = onUnauthorized {
                Task { @MainActor in cb() }
            }
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden(serverMessage(data))
        case 404:
            throw APIError.notFound(serverMessage(data))
        default:
            throw APIError.server(http.statusCode, serverMessage(data))
        }
    }

    private func serverMessage(_ data: Data) -> String {
        struct Env: Decodable { let error: String? }
        if let env = try? JSONDecoder().decode(Env.self, from: data), let m = env.error {
            return m
        }
        return ""
    }

    // MARK: - Auth

    func login(email: String, password: String) async throws -> AuthResponse {
        try await request(.POST, "/auth/login",
                          body: ["email": email, "password": password],
                          authenticated: false)
    }

    func register(name: String, email: String, password: String, role: Role) async throws -> AuthResponse {
        try await request(.POST, "/auth/register",
                          body: ["name": name, "email": email, "password": password, "role": role.rawValue],
                          authenticated: false)
    }

    func me() async throws -> User {
        try await request(.GET, "/users/me")
    }

    // MARK: - Listings

    func listings(search: String? = nil, category: String? = nil,
                  minPrice: Int? = nil, maxPrice: Int? = nil) async throws -> [Listing] {
        var q: [URLQueryItem] = []
        if let s = search, !s.isEmpty { q.append(.init(name: "search", value: s)) }
        if let c = category, !c.isEmpty { q.append(.init(name: "category", value: c)) }
        if let mn = minPrice, mn > 0 { q.append(.init(name: "minPrice", value: String(mn))) }
        if let mx = maxPrice, mx > 0 { q.append(.init(name: "maxPrice", value: String(mx))) }
        let env: ListingsEnvelope = try await request(.GET, "/listings", query: q, authenticated: false)
        return env.listings
    }

    func listing(id: String) async throws -> Listing {
        try await request(.GET, "/listings/\(id)")
    }

    func createListing(title: String, description: String, priceCents: Int,
                       category: String, photos: [String]) async throws -> Listing {
        try await request(.POST, "/listings", body: CreateListingBody(
            title: title, description: description, priceCents: priceCents,
            category: category, photos: photos))
    }

    func patchListing(id: String, patch: ListingPatch) async throws -> Listing {
        try await request(.PATCH, "/listings/\(id)", body: patch)
    }

    // MARK: - Inquiries

    func createInquiry(listingId: String, message: String) async throws -> Inquiry {
        try await request(.POST, "/inquiries",
                          body: ["listingId": listingId, "message": message])
    }

    func inquiries() async throws -> [Inquiry] {
        let env: InquiriesEnvelope = try await request(.GET, "/inquiries")
        return env.inquiries
    }

    func patchInquiry(id: String, status: InquiryStatus) async throws -> Inquiry {
        try await request(.PATCH, "/inquiries/\(id)", body: ["status": status.rawValue])
    }

    // MARK: - Favorites

    func favorites() async throws -> [FavoriteEntry] {
        let env: FavoritesEnvelope = try await request(.GET, "/favorites")
        return env.favorites
    }

    func addFavorite(listingId: String) async throws {
        _ = try await requestData(.POST, "/favorites", body: ["listingId": listingId])
    }

    func removeFavorite(listingId: String) async throws {
        _ = try await requestData(.DELETE, "/favorites/\(listingId)")
    }

    // MARK: - Reports

    func createReport(targetType: ReportTargetType, targetId: String,
                      reason: String, inquiryId: String?) async throws -> Report {
        var body: [String: String] = [
            "targetType": targetType.rawValue,
            "targetId": targetId,
            "reason": reason,
        ]
        if let inquiryId, !inquiryId.isEmpty { body["inquiryId"] = inquiryId }
        return try await request(.POST, "/reports", body: body)
    }

    func reports(status: ReportStatus? = nil) async throws -> [Report] {
        var q: [URLQueryItem] = []
        if let status, status != .unknown { q.append(.init(name: "status", value: status.rawValue)) }
        let env: ReportsEnvelope = try await request(.GET, "/reports", query: q)
        return env.reports
    }

    func report(id: String) async throws -> ReportDetail {
        try await request(.GET, "/reports/\(id)")
    }

    func patchReport(id: String, status: ReportStatus) async throws -> Report {
        try await request(.PATCH, "/reports/\(id)", body: ["status": status.rawValue])
    }

    // MARK: - Admin

    func adminUsers() async throws -> [User] {
        let env: UsersEnvelope = try await request(.GET, "/admin/users")
        return env.users
    }

    func adminPatchUser(id: String, banned: Bool? = nil, role: Role? = nil) async throws -> User {
        try await request(.PATCH, "/admin/users/\(id)", body: AdminUserPatch(banned: banned, role: role))
    }

    func adminRemoveListing(id: String) async throws -> Listing {
        try await request(.DELETE, "/admin/listings/\(id)")
    }

    func adminAudit() async throws -> [AuditEntry] {
        let env: AuditEnvelope = try await request(.GET, "/admin/audit")
        return env.audit
    }
}

// MARK: - Request bodies

struct CreateListingBody: Encodable {
    let title: String
    let description: String
    let priceCents: Int
    let category: String
    let photos: [String]
}

/// Partial listing update. Only non-nil fields are sent (matches the backend's
/// pointer-field PATCH semantics).
struct ListingPatch: Encodable {
    var title: String?
    var description: String?
    var priceCents: Int?
    var category: String?
    var photos: [String]?
    var status: ListingStatus?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(priceCents, forKey: .priceCents)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encodeIfPresent(photos, forKey: .photos)
        try c.encodeIfPresent(status?.rawValue, forKey: .status)
    }

    enum CodingKeys: String, CodingKey {
        case title, description, priceCents, category, photos, status
    }
}

struct AdminUserPatch: Encodable {
    var banned: Bool?
    var role: Role?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(banned, forKey: .banned)
        try c.encodeIfPresent(role?.rawValue, forKey: .role)
    }

    enum CodingKeys: String, CodingKey { case banned, role }
}

// MARK: - Encoding helpers

/// Type-erased Encodable so `request(body:)` can accept dictionaries and structs.
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: Encodable) {
        encodeFunc = wrapped.encode
    }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}

/// Placeholder for endpoints that return no body (204).
struct EmptyResponse: Decodable {}
