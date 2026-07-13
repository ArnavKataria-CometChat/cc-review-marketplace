import SwiftUI

/// A reusable sheet for filing a report/dispute. Any authenticated user can
/// report a listing, user or message; passing an `inquiryId` links the report
/// to a thread (the Phase B escalation seam).
struct ReportSheet: View {
    let targetType: ReportTargetType
    let targetId: String
    var inquiryId: String? = nil
    var title: String = "Report"

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var reason = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            Form {
                if didSubmit {
                    Section {
                        Label("Report submitted. Support will review it.",
                              systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Section("Reason") {
                        TextField("Describe the issue", text: $reason, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    Section {
                        LabeledContent("Target", value: targetType.rawValue.capitalized)
                        if inquiryId != nil {
                            Label("This will dispute the linked inquiry thread.",
                                  systemImage: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let errorMessage {
                        Section { InlineError(message: errorMessage) }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didSubmit ? "Done" : "Cancel") { dismiss() }
                }
                if !didSubmit {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit", action: submit)
                            .disabled(isSubmitting || reason.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                _ = try await session.api.createReport(
                    targetType: targetType, targetId: targetId,
                    reason: reason, inquiryId: inquiryId)
                withAnimation { didSubmit = true }
            } catch {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
