import SwiftUI

// MARK: - Palette

extension Color {
    /// Light sky blue used for splash / welcome backgrounds. #AEE0F5
    static let mvSky = Color(red: 0xAE / 255, green: 0xE0 / 255, blue: 0xF5 / 255)
    /// Primary brand accent. #5B8FB0
    static let mvAccent = Color(red: 0x5B / 255, green: 0x8F / 255, blue: 0xB0 / 255)
    /// Primary dark text. #1F2A37
    static let mvInk = Color(red: 0x1F / 255, green: 0x2A / 255, blue: 0x37 / 255)
    /// Secondary / muted text. #8A98A8
    static let mvSubtle = Color(red: 0x8A / 255, green: 0x98 / 255, blue: 0xA8 / 255)
    /// Hairline borders on inputs / cards. #C7D9E2
    static let mvBorder = Color(red: 0xC7 / 255, green: 0xD9 / 255, blue: 0xE2 / 255)

    /// Create a Color from a 6-digit hex string (e.g. "5B8FB0").
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Screen background

/// White → sky vertical gradient used across the onboarding/auth flow.
struct MVScreenBackground: ViewModifier {
    /// When true, uses a solid sky fill (splash / welcome) instead of the gradient.
    var solid: Bool = false

    func body(content: Content) -> some View {
        content.background(
            Group {
                if solid {
                    Color.mvSky
                } else {
                    LinearGradient(
                        colors: [.white, .mvSky],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .ignoresSafeArea()
        )
    }
}

extension View {
    func mvScreenBackground(solid: Bool = false) -> some View {
        modifier(MVScreenBackground(solid: solid))
    }
}

// MARK: - Glass card

/// Translucent frosted card with a hairline white border and soft shadow,
/// mirroring the material treatment used in the Scan feature.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    var selected: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                (selected ? Color.mvAccent.opacity(0.18) : Color.white.opacity(0.45)),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        selected ? Color.mvAccent.opacity(0.6) : Color.white.opacity(0.6),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
            .shadow(color: Color.mvAccent.opacity(0.16), radius: 16, x: 0, y: 8)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16, selected: Bool = false) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, selected: selected))
    }
}

// MARK: - Primary button

/// Filled accent pill used for the primary call-to-action on every screen.
struct MVPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(
                (enabled ? Color.mvAccent : Color.mvAccent.opacity(0.35)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(
                color: enabled ? Color.mvAccent.opacity(0.35) : .clear,
                radius: 14, x: 0, y: 4
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
