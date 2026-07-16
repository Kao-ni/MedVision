import SwiftUI

struct TermsPlaceholderView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Terms of Service")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Terms and conditions will be added here later.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Continue", action: onContinue)
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
        .padding(.bottom, 52)
        .background(Color(.systemBackground))
    }
}

#Preview {
    TermsPlaceholderView {}
}
