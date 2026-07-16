import SwiftUI

struct TermsPlaceholderView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Terms of Service")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.mvInk)
                .multilineTextAlignment(.center)

            Text("Terms and conditions will be added here later.")
                .font(.title3)
                .foregroundStyle(Color.mvSubtle)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Continue", action: onContinue)
                .buttonStyle(MVPrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mvScreenBackground()
    }
}

#Preview {
    TermsPlaceholderView {}
}
