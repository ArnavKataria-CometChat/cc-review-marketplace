import Foundation

// Go's encoding/json emits time.Time as RFC 3339 with a variable number of
// fractional-second digits (up to 9 / nanoseconds), e.g.
//   2026-07-13T12:34:56Z
//   2026-07-13T12:34:56.123Z
//   2026-07-13T12:34:56.123456789Z
// Foundation's ISO8601DateFormatter is strict about the number of fractional
// digits, so we parse leniently: try a few formatters, then fall back to
// trimming fractional seconds.
enum APICoding {

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = parseDate(raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(raw)"
            )
        }
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let withoutFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseDate(_ raw: String) -> Date? {
        if let d = withFraction.date(from: raw) { return d }
        if let d = withoutFraction.date(from: raw) { return d }
        // Normalize an arbitrary-precision fractional part down to 3 digits
        // (milliseconds), which the fractional formatter accepts.
        if let normalized = normalizeFraction(raw),
           let d = withFraction.date(from: normalized) {
            return d
        }
        return nil
    }

    /// Trims the fractional-seconds component to at most 3 digits.
    private static func normalizeFraction(_ raw: String) -> String? {
        guard let dot = raw.firstIndex(of: ".") else { return nil }
        let afterDot = raw.index(after: dot)
        // Find where the fractional digits end (the timezone/`Z` designator).
        var end = afterDot
        while end < raw.endIndex, raw[end].isNumber {
            end = raw.index(after: end)
        }
        let digits = raw[afterDot..<end]
        let suffix = raw[end...]           // e.g. "Z" or "+00:00"
        let trimmed = digits.prefix(3)
        return "\(raw[..<afterDot])\(trimmed)\(suffix)"
    }
}
