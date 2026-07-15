import AuthenticationServices
import Foundation
import Supabase

enum AuthServiceError: LocalizedError {
    case notConfigured
    case missingAppleIDToken
    case invalidAppleCredential
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Add your Supabase URL and anon key in SupabaseSecrets.swift first. See Config/AUTH_SETUP.md."
        case .missingAppleIDToken:
            return "Apple did not return a sign-in token. Try again."
        case .invalidAppleCredential:
            return "Apple sign-in returned an unexpected credential."
        case .message(let text):
            return text
        }
    }
}

/// Owns the Supabase client and exposes auth operations for the UI.
@MainActor
@Observable
final class AuthService {
    private(set) var session: Session?
    private(set) var isRestoringSession = true
    private(set) var isConfigured: Bool

    let client: SupabaseClient
    private var authListenerTask: Task<Void, Never>?

    init(client: SupabaseClient = SupabaseConfig.makeClient()) {
        self.client = client
        self.isConfigured = SupabaseConfig.isConfigured
        startAuthListener()
        Task { await restoreSession() }
    }

    var isSignedIn: Bool { session != nil }

    var userEmail: String? {
        session?.user.email
    }

    var userDisplayName: String? {
        let meta = session?.user.userMetadata
        if let full = meta?["full_name"]?.stringValue, !full.isEmpty { return full }
        if let name = meta?["name"]?.stringValue, !name.isEmpty { return name }
        return nil
    }

    func restoreSession() async {
        guard isConfigured else {
            session = nil
            isRestoringSession = false
            return
        }
        do {
            session = try await client.auth.session
        } catch {
            session = nil
        }
        isRestoringSession = false
    }

    func signUp(email: String, password: String) async throws {
        try ensureConfigured()
        let response = try await client.auth.signUp(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        if let session = response.session {
            self.session = session
        } else {
            // Email confirmation may be required in the project settings.
            throw AuthServiceError.message(
                "Account created. Check your email to confirm, then sign in."
            )
        }
    }

    func signIn(email: String, password: String) async throws {
        try ensureConfigured()
        session = try await client.auth.signIn(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
    }

    func signInWithApple(idToken: String, fullName: PersonNameComponents?) async throws {
        try ensureConfigured()
        _ = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken
            )
        )
        session = try await client.auth.session

        if let fullName {
            var parts: [String] = []
            if let given = fullName.givenName, !given.isEmpty { parts.append(given) }
            if let middle = fullName.middleName, !middle.isEmpty { parts.append(middle) }
            if let family = fullName.familyName, !family.isEmpty { parts.append(family) }
            let fullNameString = parts.joined(separator: " ")
            guard !fullNameString.isEmpty else { return }
            try await client.auth.update(
                user: UserAttributes(
                    data: [
                        "full_name": .string(fullNameString),
                        "given_name": .string(fullName.givenName ?? ""),
                        "family_name": .string(fullName.familyName ?? "")
                    ]
                )
            )
            session = try await client.auth.session
        }
    }

    func signInWithGoogle() async throws {
        try ensureConfigured()
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: SupabaseConfig.oauthRedirectURL
        ) { (session: ASWebAuthenticationSession) in
            session.prefersEphemeralWebBrowserSession = false
        }
        self.session = try await client.auth.session
    }

    func handleOpenURL(_ url: URL) {
        guard isConfigured else { return }
        client.auth.handle(url)
    }

    func signOut() async throws {
        try ensureConfigured()
        try await client.auth.signOut()
        session = nil
    }

    private func ensureConfigured() throws {
        guard isConfigured else { throw AuthServiceError.notConfigured }
    }

    private func startAuthListener() {
        authListenerTask?.cancel()
        guard isConfigured else { return }
        authListenerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await (event, session) in await self.client.auth.authStateChanges {
                switch event {
                case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                    self.session = session
                    self.isRestoringSession = false
                case .signedOut:
                    self.session = nil
                    self.isRestoringSession = false
                default:
                    break
                }
            }
        }
    }
}

private extension AnyJSON {
    var stringValue: String? {
        switch self {
        case .string(let value): return value
        default: return nil
        }
    }
}
