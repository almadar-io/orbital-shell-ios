import SwiftUI

/// Accessibility identifiers of the host sign-in route, addressed by the verify driver's `/tap` and `/type`.
enum SignInIds {
    static let title = "signin-title"
    static let email = "field-signin-email"
    static let password = "field-signin-password"
    static let submit = "action-signin-submit"
    static let signOut = "action-signin-signout"
    static let error = "signin-error"
    static let status = "signin-status"
    static func persona(_ id: String) -> String { "action-signin-persona-" + id }
}

/// The host's sign-in route (`HOST_SIGN_IN_ROUTE`, `/login`): the native twin of the web template's
/// `Login` and dev `PersonaSwitcher`. The provider call and the session live in `OrbitalAuth`; this
/// view only collects input and shows the outcome. A failure is shown here and nothing is signed in.
struct OrbitalSignInView: View {
    @ObservedObject var viewModel: OrbitalViewModel
    @Environment(\.almadarTheme) private var theme
    @State private var email = ""
    @State private var password = ""
    @State private var personas: [OrbitalPersona] = []
    @State private var failure: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sign in")
                    .font(.title).bold()
                    .foregroundColor(theme.color.foreground)
                    .accessibilityIdentifier(SignInIds.title)
                if !viewModel.auth.isConfigured {
                    Text("Sign-in is not configured for this build.")
                        .foregroundColor(theme.color.mutedForeground)
                        .accessibilityIdentifier(SignInIds.status)
                } else if let session = viewModel.session {
                    Text("Signed in as \(session.uid)")
                        .foregroundColor(theme.color.foreground)
                        .accessibilityIdentifier(SignInIds.status)
                    Button("Sign out") { viewModel.signOut() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier(SignInIds.signOut)
                } else {
                    form
                }
                if let failure = failure {
                    Text(failure)
                        .foregroundColor(theme.color.error)
                        .accessibilityIdentifier(SignInIds.error)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.color.background.ignoresSafeArea())
        .task { personas = await viewModel.auth.personas(apiBase: viewModel.apiBase) }
    }

    @ViewBuilder
    private var form: some View {
        TextField("Email address", text: $email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier(SignInIds.email)
        SecureField("Password", text: $password)
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier(SignInIds.password)
        Button(busy ? "Signing in..." : "Sign in") {
            run { try await viewModel.auth.signIn(email: email, password: password) }
        }
        .buttonStyle(.borderedProminent)
        .disabled(busy)
        .accessibilityIdentifier(SignInIds.submit)
        if !personas.isEmpty {
            Text("Dev personas")
                .font(.caption)
                .foregroundColor(theme.color.mutedForeground)
            ForEach(personas, id: \.id) { persona in
                Button(persona.label) {
                    run { try await viewModel.auth.signInAsPersona(id: persona.id, apiBase: viewModel.apiBase) }
                }
                .buttonStyle(.bordered)
                .disabled(busy)
                .accessibilityIdentifier(SignInIds.persona(persona.id))
            }
        }
    }

    private func run(_ signIn: @escaping () async throws -> Void) {
        failure = nil
        busy = true
        Task {
            do {
                try await signIn()
            } catch {
                failure = error.localizedDescription
            }
            busy = false
        }
    }
}
