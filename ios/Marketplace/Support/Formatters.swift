import Foundation

enum Format {
    /// Formats integer cents as a localized currency string, e.g. 24500 -> "$245.00".
    static func price(_ cents: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "$\(cents / 100)"
    }

    /// Short relative-ish date, e.g. "Jul 13, 2026".
    static func date(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    static func dateTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}

/// Categories the seed data uses; also offered in the create/filter UI. Free
/// text is still allowed by the backend, but these keep the demo tidy.
enum Categories {
    static let all = ["electronics", "furniture", "sports", "clothing", "books", "other"]
}
