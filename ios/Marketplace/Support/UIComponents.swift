import SwiftUI

// MARK: - Status & role badges

struct RoleBadge: View {
    let role: Role
    var body: some View {
        Text(role.label.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
    private var color: Color {
        switch role {
        case .buyer: return .blue
        case .seller: return .green
        case .support: return .orange
        case .admin: return .purple
        case .unknown: return .gray
        }
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

extension ListingStatus {
    var pillColor: Color {
        switch self {
        case .active: return .green
        case .sold: return .gray
        case .removed: return .red
        case .unknown: return .gray
        }
    }
    var label: String {
        switch self {
        case .active: return "active"
        case .sold: return "sold"
        case .removed: return "removed"
        case .unknown: return "unknown"
        }
    }
}

extension InquiryStatus {
    var pillColor: Color { self == .open ? .green : .gray }
    var label: String {
        switch self {
        case .open: return "open"
        case .closed: return "closed"
        case .unknown: return "unknown"
        }
    }
}

extension ReportStatus {
    var pillColor: Color {
        switch self {
        case .open: return .blue
        case .flagged: return .orange
        case .resolved: return .green
        case .unknown: return .gray
        }
    }
    var label: String {
        switch self {
        case .open: return "open"
        case .flagged: return "flagged"
        case .resolved: return "resolved"
        case .unknown: return "unknown"
        }
    }
}

// MARK: - Async content wrapper

/// Drives a simple load / loaded / error state machine for a screen's data.
enum Loadable<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

/// A reusable view that shows a spinner, an error with retry, or content.
struct LoadableView<Value, Content: View>: View {
    let state: Loadable<Value>
    let retry: () -> Void
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let value):
            content(value)
        case .failed(let message):
            ErrorState(message: message, retry: retry)
        }
    }
}

struct ErrorState: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: retry).buttonStyle(.borderedProminent)
        }
    }
}

struct EmptyState: View {
    let title: String
    let systemImage: String
    var description: String? = nil
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let description { Text(description) }
        }
    }
}

// MARK: - Inline error banner (for form actions)

struct InlineError: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
