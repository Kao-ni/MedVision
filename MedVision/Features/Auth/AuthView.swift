import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(AuthService.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.mvSurface.opacity(colorScheme == .dark ? 0.68 : 0.72))
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
                .tint(Color.mvAccent)
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
                            .font(.headline)
                            .foregroundStyle(Color.mvOnAccent)
                            .fontWeight(.semibold)
                            .opacity(viewModel.isLoading ? 0 : 1)
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(Color.mvOnAccent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 60)
                    .padding(.horizontal, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.mvAccentGradientStart, Color.mvAccentGradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        Task { await viewModel.handleAppleResult(result) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .whiteOutline : .white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                            icon: .system("g.circle.fill")
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
                            icon: .system("person.crop.circle.fill")
                        )
                    }
                    .buttonStyle(.plain)
                    .modifier(SignInOptionStyle(isDisabled: viewModel.isLoading))
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel(Text("Continue as guest without signing in"))
                }

                Text("You’ll stay signed in on this phone until you sign out.")
                    .font(.caption)
                    .foregroundStyle(Color.mvSubtle)
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
            .foregroundStyle(Color.mvInk)
            .tint(Color.mvAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .modifier(AuthRectangleStyle(cornerRadius: 14))
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
    let icon: SignInOptionIcon

    enum SignInOptionIcon {
        case system(String)
    }

    var body: some View {
            HStack(spacing: 10) {
                iconView
                    .frame(width: 26, height: 26, alignment: .center)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .foregroundStyle(Color.mvInk)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 20, weight: .medium))
        }
    }
}

private struct SignInOptionStyle: ViewModifier {
    let isDisabled: Bool

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(Color.mvInk)
            .modifier(AuthRectangleStyle(cornerRadius: 18))
            .opacity(isDisabled ? 0.5 : 1)
    }
}

private struct AuthRectangleStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                Color.mvSurface.opacity(colorScheme == .dark ? 0.68 : 0.72),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.mvBorder.opacity(0.65), lineWidth: 1)
            }
            .shadow(color: Color.mvAccent.opacity(0.12), radius: 14, x: 0, y: 8)
    }
}
