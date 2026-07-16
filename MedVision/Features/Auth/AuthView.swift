import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(AuthService.self) private var auth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MedVision")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)

                    Text(viewModel.mode == .signIn
                       ? "Sign in to continue"
                       : "Create your account")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                Picker("Mode", selection: $viewModel.mode) {
                    ForEach(AuthViewModel.Mode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Sign in or create account")
                .disabled(viewModel.isLoading)

                VStack(spacing: 16) {
                    authField(
                        title: "Email",
                        text: $viewModel.email,
                        contentType: .emailAddress,
                        keyboard: .emailAddress,
                        isSecure: false
                    )

                    authField(
                        title: "Password",
                        text: $viewModel.password,
                        contentType: viewModel.mode == .signUp ? .newPassword : .password,
                        keyboard: .default,
                        isSecure: true
                    )

                    if viewModel.mode == .signUp {
                        authField(
                            title: "Confirm password",
                            text: $viewModel.confirmPassword,
                            contentType: .newPassword,
                            keyboard: .default,
                            isSecure: true
                        )
                    }
                }

                if let error = viewModel.errorMessage {
                    messageBanner(text: error, tint: .red, icon: "exclamationmark.triangle.fill")
                }

                if let info = viewModel.infoMessage {
                    messageBanner(text: info, tint: .blue, icon: "envelope.fill")
                }

                Button {
                    Task { await viewModel.submit() }
                } label: {
                    ZStack {
                        Text(viewModel.primaryButtonTitle)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .opacity(viewModel.isLoading ? 0 : 1)
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading || !auth.isConfigured)
                .accessibilityLabel(viewModel.primaryButtonTitle)

                VStack(spacing: 12) {
                    Text("Or continue with")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        Task { await viewModel.handleAppleResult(result) }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 56)
                    .disabled(viewModel.isLoading || !auth.isConfigured)
                    .accessibilityLabel("Sign in with Apple")

                    Button {
                        Task { await viewModel.signInWithGoogle() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text("Continue with Google")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoading || !auth.isConfigured)
                    .accessibilityLabel("Continue with Google")
                }

                Button {
                    viewModel.continueAsGuest()
                } label: {
                    Text("Continue as Guest")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Continue as guest without signing in")

                Text("You’ll stay signed in on this phone until you sign out.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
    }

    private func authField(
        title: String,
        text: Binding<String>,
        contentType: UITextContentType?,
        keyboard: UIKeyboardType,
        isSecure: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Group {
                if isSecure {
                    SecureField(title, text: text)
                } else {
                    TextField(title, text: text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(keyboard)
                }
            }
            .textContentType(contentType)
            .font(.title3)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel(title)
        }
    }

    private func messageBanner(text: String, tint: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.title3)
            Text(text)
                .font(.body)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}
