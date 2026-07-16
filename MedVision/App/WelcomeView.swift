import SwiftUI

/// Multilingual welcome shown right after the splash. A crossfading
/// "hello" ↔ "สวัสดี" greeting over the sky background; tapping anywhere
/// advances the flow.
struct WelcomeView: View {
    let onContinue: () -> Void

    @State private var showThai = false

    var body: some View {
        ZStack {
            Color.mvSky.ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Text("hello")
                        .font(.system(size: 72, weight: .semibold, design: .serif))
                        .italic()
                        .opacity(showThai ? 0 : 1)

                    Text(verbatim: "สวัสดี")
                        .font(.system(size: 60, weight: .bold))
                        .opacity(showThai ? 1 : 0)
                }
                .foregroundStyle(.white)
                .frame(height: 110)

                Text("Tap to continue")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onContinue)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                showThai = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Welcome to MedVision"))
        .accessibilityHint(Text("Tap to continue"))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
