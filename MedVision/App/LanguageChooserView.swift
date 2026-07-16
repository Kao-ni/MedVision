import SwiftUI

/// Pre-auth language chooser. Two glass cards (English / ไทย) writing the
/// shared `profile_displayLanguage` key that drives the app locale.
struct LanguageChooserView: View {
    let onContinue: () -> Void

    @AppStorage(AppLanguage.storageKey) private var storedDisplayLanguage = ""
    @State private var selection: String?

    private struct Option: Identifiable {
        let id: String
        let badge: String
        let nativeName: String
    }

    private let options: [Option] = [
        Option(id: "en", badge: "🇺🇸", nativeName: "English"),
        Option(id: "th", badge: "🇹🇭", nativeName: "ไทย")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Choose your language")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.mvInk)
                .multilineTextAlignment(.center)
                .padding(.bottom, 28)

            VStack(spacing: 14) {
                ForEach(options) { option in
                    languageCard(option)
                }
            }

            Spacer()

            Button("Continue") {
                if let selection {
                    storedDisplayLanguage = AppLanguage.code(for: selection)
                    onContinue()
                }
            }
            .buttonStyle(MVPrimaryButtonStyle(enabled: selection != nil))
            .disabled(selection == nil)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mvScreenBackground()
    }

    private func languageCard(_ option: Option) -> some View {
        let isSelected = selection == option.id
        return Button {
            selection = option.id
        } label: {
            HStack(spacing: 14) {
                Text(verbatim: option.badge)
                    .font(.system(size: 37, weight: .bold))
                    .foregroundStyle(Color.mvAccent)
                    .frame(width: 54, height: 54)
                    .background(Color.white.opacity(0.55), in: Circle())

                Text(verbatim: option.nativeName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.mvInk)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.mvAccent : Color(hex: "D8DEE4"), lineWidth: 2)
                        .frame(width: 36, height: 56)
                    if isSelected {
                        Circle()
                            .fill(Color.mvAccent)
                            .frame(width: 36, height: 36)
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(18)
            .glassCard(selected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LanguageChooserView(onContinue: {})
}
