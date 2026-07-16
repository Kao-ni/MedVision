import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(AuthService.self) private var auth

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: 92, height: 92)

                        Image(systemName: "pills.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(Color.mvAccent)
                    }

                    VStack(spacing: 4) {
                        Text(
                            LocalizedStringKey(
                                viewModel.mode == .signIn
                                    ? "Welcome to MedVision"
                                    : "Create Your Account"
                            )
                        )
                        .font(.title.bold())
                        .foregroundStyle(Color.mvInk)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                        Text(
                            LocalizedStringKey(
                                viewModel.mode == .signIn
                                    ? "Sign in to continue managing your medicines."
                                    : "Create an account to keep your medicine information together."
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(Color.mvSubtle)
                        .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 8)

                Picker("Mode", selection: $viewModel.mode) {
                    ForEach(AuthViewModel.Mode.allCases, id: \.self) { mode in
                        Text(LocalizedStringKey(mode.titleKey)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .tint(.black)
                .accessibilityLabel(Text("Sign in or create account"))
                .disabled(viewModel.isLoading)
                .padding(4)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(spacing: 10) {
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
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                            .opacity(viewModel.isLoading ? 0 : 1)
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading || !auth.isConfigured)
                .opacity(viewModel.isLoading || !auth.isConfigured ? 0.5 : 1)
                .accessibilityLabel(viewModel.primaryButtonTitle)

                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 1)
                    Text("Or continue with")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 1)
                }

                VStack(spacing: 8) {
                    ZStack {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.email, .fullName]
                        } onCompletion: { result in
                            Task { await viewModel.handleAppleResult(result) }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .opacity(0.02)

                        SignInOptionLabel(
                            title: "Sign in with Apple",
                            icon: "apple.logo"
                        )
                        .allowsHitTesting(false)
                    }
                    .modifier(SignInOptionStyle(
                        isDisabled: viewModel.isLoading || !auth.isConfigured
                    ))
                    .disabled(viewModel.isLoading || !auth.isConfigured)
                    .accessibilityLabel(Text("Sign in with Apple"))

                    Button {
                        Task { await viewModel.signInWithGoogle() }
                    } label: {
                        SignInOptionLabel(
                            title: "Continue with Google",
                            icon: "g.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)
                    .modifier(SignInOptionStyle(
                        isDisabled: viewModel.isLoading || !auth.isConfigured
                    ))
                    .disabled(viewModel.isLoading || !auth.isConfigured)
                    .accessibilityLabel(Text("Continue with Google"))

                    Button {
                        viewModel.continueAsGuest()
                    } label: {
                        SignInOptionLabel(
                            title: "Continue as Guest",
                            icon: "person.crop.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)
                    .modifier(SignInOptionStyle(isDisabled: viewModel.isLoading))
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel(Text("Continue as guest without signing in"))
                }

                Text("You’ll stay signed in on this phone until you sign out.")
                    .font(.caption)
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
        }
        .mvScreenBackground()
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    private func authField(
        title: LocalizedStringKey,
        text: Binding<String>,
        contentType: UITextContentType?,
        keyboard: UIKeyboardType,
        isSecure: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mvAccent)
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
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.85))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.mvBorder, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel(Text(title))
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

private struct SignInOptionLabel: View {
    let title: LocalizedStringKey
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 26, alignment: .center)

            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .foregroundStyle(Color.mvInk)
    }
}

private struct SignInOptionStyle: ViewModifier {
    let isDisabled: Bool

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(Color.mvInk)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .opacity(isDisabled ? 0.5 : 1)
    }
}
