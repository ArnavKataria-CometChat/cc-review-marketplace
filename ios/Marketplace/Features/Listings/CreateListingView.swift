import SwiftUI

struct CreateListingView: View {
    var onCreated: () -> Void

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var priceDollars = ""
    @State private var category = Categories.all.first ?? "other"
    @State private var photosText = ""
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Price & category") {
                    HStack {
                        Text("$")
                        TextField("0.00", text: $priceDollars)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Category", selection: $category) {
                        ForEach(Categories.all, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
                Section("Photos") {
                    TextField("Image URLs (comma-separated)", text: $photosText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Optional. Enter one or more image URLs separated by commas.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Section { InlineError(message: errorMessage) }
                }
            }
            .navigationTitle("New Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: submit)
                        .disabled(busy || !isValid)
                }
            }
        }
    }

    private var priceCents: Int? {
        guard let dollars = Double(priceDollars), dollars > 0 else { return nil }
        return Int((dollars * 100).rounded())
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && priceCents != nil
    }

    private func submit() {
        guard let cents = priceCents else { return }
        errorMessage = nil
        busy = true
        let photos = photosText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        Task {
            do {
                _ = try await session.api.createListing(
                    title: title, description: description,
                    priceCents: cents, category: category, photos: photos)
                onCreated()
                dismiss()
            } catch {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
            busy = false
        }
    }
}
