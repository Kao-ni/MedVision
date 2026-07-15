import AuthenticationServices
import Foundation

@MainActor
@Observable
final class AuthViewModel {
    enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Create Account"
    }

    var mode: Mode = .signIn
    var email = ""
    var password = ""
    var confirmPassword = ""
    var errorMessage: String?
    var infoMessage: String?
    var isLoading = false

    private let auth: AuthService

    init(auth: AuthService) {
        self.auth = auth
    }

    var primaryButtonTitle: String {
        mode == .signIn ? "Sign In" : "Create Account"
    }

    func submit() async {
        errorMessage = nil
        infoMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Enter your email address."
            return
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        if mode == .signUp {
            guard password == confirmPassword else {
                errorMessage = "Passwords do not match."
                return
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .signIn:
                try await auth.signIn(email: trimmedEmail, password: password)
            case .signUp:
                try await auth.signUp(email: trimmedEmail, password: password)
            }
        } catch {
            let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if text.localizedCaseInsensitiveContains("check your email") {
                infoMessage = text
                errorMessage = nil
            } else {
                errorMessage = text
            }
        }
    }

    func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        infoMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthServiceError.invalidAppleCredential
            }
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                throw AuthServiceError.missingAppleIDToken
            }
            try await auth.signInWithApple(idToken: idToken, fullName: credential.fullName)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func signInWithGoogle() async {
        errorMessage = nil
        infoMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await auth.signInWithGoogle()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
