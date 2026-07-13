import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var name = ""
    @State private var role: Role = .buyer
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showServerField = false
    @State private var serverURL = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 6) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                        Text("Marketplace")
                            .font(.title.bold())
                        Text(isRegistering ? "Create your account" : "Buy and sell locally")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    if isRegistering {
                        TextField("Full name", text: $name)
                            .textContentType(.name)
                    }
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)

                    if isRegistering {
                        Picker("I want to", selection: $role) {
                            Text("Buy items").tag(Role.buyer)
                            Text("Sell items").tag(Role.seller)
                        }
                    }
                }

                if let errorMessage {
                    Section { InlineError(message: errorMessage) }
                }

                Section {
                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if isSubmitting { ProgressView() }
                            else { Text(isRegistering ? "Create Account" : "Sign In").bold() }
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting || !isValid)

                    Button(isRegistering ? "Have an account? Sign in"
                                         : "New here? Create an account") {
                        withAnimation { isRegistering.toggle(); errorMessage = nil }
                    }
                    .font(.footnote)
                }

                if !isRegistering {
                    Section("Demo accounts") {
                        ForEach(demoAccounts, id: \.email) { acct in
                            Button {
                                email = acct.email
                                password = "Password123!"
                            } label: {
                                HStack {
                                    Text(acct.label)
                                    Spacer()
                                    Text(acct.email).foregroundStyle(.secondary).font(.footnote)
                                }
                            }
                        }
                        Text("All demo accounts use the password Password123!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    DisclosureGroup("Backend server", isExpanded: $showServerField) {
                        TextField("http://localhost:8080", text: $serverURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        Button("Save server URL") {
                            AppConfig.setBaseURLOverride(serverURL)
                        }
                        .font(.footnote)
                        Text("Points the app at your Go/Gin backend. Default: http://localhost:8080")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isRegistering ? "Register" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var isValid: Bool {
        guard email.contains("@"), password.count >= (isRegistering ? 8 : 1) else { return false }
        if isRegistering { return !name.trimmingCharacters(in: .whitespaces).isEmpty }
        return true
    }

    private func submit() {
        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                if isRegistering {
                    try await session.register(name: name, email: email, password: password, role: role)
                } else {
                    try await session.login(email: email, password: password)
                }
            } catch {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
            isSubmitting = false
        }
    }

    private struct Demo { let label: String; let email: String }
    private var demoAccounts: [Demo] {
        [
            .init(label: "Buyer", email: "buyer@example.com"),
            .init(label: "Seller", email: "seller@example.com"),
            .init(label: "Support", email: "support@example.com"),
            .init(label: "Admin", email: "admin@example.com"),
        ]
    }
}
