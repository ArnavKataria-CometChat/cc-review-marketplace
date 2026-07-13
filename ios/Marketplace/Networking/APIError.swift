import Foundation

/// A typed error surfaced to the UI. `message` is safe to show to users.
enum APIError: LocalizedError, Equatable {
    case invalidURL
    case transport(String)          // network/offline/DNS failure
    case decoding(String)           // response body could not be parsed
    case unauthorized               // 401 — token missing/expired
    case forbidden(String)          // 403 — RBAC denied
    case notFound(String)           // 404
    case server(Int, String)        // any other non-2xx with server message

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The server address is invalid."
        case .transport(let m):
            return "Network error: \(m)"
        case .decoding(let m):
            return "Could not read the server response. \(m)"
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden(let m):
            return m.isEmpty ? "You don't have permission to do that." : m
        case .notFound(let m):
            return m.isEmpty ? "Not found." : m
        case .server(_, let m):
            return m.isEmpty ? "Something went wrong on the server." : m
        }
    }

    /// True when the caller should force a sign-out.
    var isAuthFailure: Bool {
        if case .unauthorized = self { return true }
        return false
    }
}
