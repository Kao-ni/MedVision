import AuthenticationServices
import Foundation

@MainActor
@Observable
final class AuthViewModel {
    enum Mode: CaseIterable {
        case signIn
        case signUp

        var titleKey: String {
            switch self {
            case .signIn: return "Sign In"
            case .signUp: return "Create Account"
            }
        }
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
        AppLanguage.localized(mode.titleKey)
    }

    func submit() async {
        errorMessage = nil
        infoMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            errorMessage = AppLanguage.localized("Enter your email address.")
            return
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = AppLanguage.localized("Enter a valid email address.")
            return
        }
        guard password.count >= 6 else {
            errorMessage = AppLanguage.localized("Password must be at least 6 characters.")
            return
        }
        if mode == .signUp {
            guard password == confirmPassword else {
                errorMessage = AppLanguage.localized("Passwords do not match.")
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
            if text.localizedCaseInsensitiveContains("check your email")
                || text.localizedCaseInsensitiveContains("ตรวจสอบอีเมล") {
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

    func continueAsGuest() {
        auth.continueAsGuest()
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
