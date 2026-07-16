import SwiftUI
import UIKit

// MARK: - Palette

extension Color {
    static let mvSky = adaptive(light: 0xAEE0F5, dark: 0x17394A)
    static let mvAccent = adaptive(light: 0x5B8FB0, dark: 0x74B5D7)
    static let mvInk = adaptive(light: 0x1F2A37, dark: 0xF3F8FB)
    static let mvSubtle = adaptive(light: 0x64748B, dark: 0xA8BAC6)
    static let mvBorder = adaptive(light: 0xC7D9E2, dark: 0x456677)
    static let mvSurface = adaptive(light: 0xFFFFFF, dark: 0x18313E)
    static let mvSurfaceStrong = adaptive(light: 0xF7FBFD, dark: 0x203E4D)
    static let mvSuccess = adaptive(light: 0x4F8A5F, dark: 0x79C58B)
    static let mvWarning = adaptive(light: 0xB86C2E, dark: 0xF0A35E)
    static let mvDanger = adaptive(light: 0xB64C4C, dark: 0xF08080)
    static let mvOnAccent = adaptive(light: 0xFFFFFF, dark: 0x07141C)
    static let mvAccentGradientStart = adaptive(light: 0x5F91AF, dark: 0x8ECBEA)
    static let mvAccentGradientEnd = adaptive(light: 0x3F708E, dark: 0x62AACD)

    static func adaptive(light: Int, dark: Int) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8) / 255,
            blue: Double(value & 0x0000FF) / 255
        )
    }
}

private extension UIColor {
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Backgrounds and surfaces

struct MVScreenBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var solid: Bool = false

    func body(content: Content) -> some View {
        content.background {
            Group {
                if solid {
                    Color.mvSky
                } else {
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color(hex: "0C1C25"), Color.mvSky]
                            : [.white, Color.mvSky],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .ignoresSafeArea()
        }
    }
}

extension View {
    func mvScreenBackground(solid: Bool = false) -> some View {
        modifier(MVScreenBackground(solid: solid))
    }
}

struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 18
    var selected: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                selected
                    ? Color.mvAccent.opacity(colorScheme == .dark ? 0.28 : 0.18)
                    : Color.mvSurface.opacity(colorScheme == .dark ? 0.62 : 0.55),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        selected ? Color.mvAccent.opacity(0.7) : Color.mvBorder.opacity(0.55),
                        lineWidth: selected ? 1.5 : 1
                    )
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08),
                radius: 18,
                x: 0,
                y: 8
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 18, selected: Bool = false) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, selected: selected))
    }
}

// MARK: - Shared components

struct MVSectionHeader: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil
    var tint: Color = .mvSubtle

    var body: some View {
        HStack(spacing: 7) {
            if let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(title)
        }
        .font(.system(size: 13, weight: .bold))
        .textCase(.uppercase)
        .tracking(0.6)
        .foregroundStyle(tint)
    }
}

struct MVIconTile: View {
    let systemImage: String
    var tint: Color = .mvAccent
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct MVMedicineThumbnail: View {
    var photoData: Data?
    var form: MedicineForm
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: form.systemImage)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Color.mvAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.mvAccent.opacity(0.14))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .stroke(Color.mvBorder.opacity(0.55), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

struct MVEmptyState: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 14) {
            MVIconTile(systemImage: systemImage, tint: .mvAccent, size: 64)
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.mvInk)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(Color.mvSubtle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .padding(24)
    }
}

struct MVStatusBadge: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.13), in: Capsule())
    }
}

// MARK: - Buttons

struct MVPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)

        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Color.mvOnAccent)
            .background(
                LinearGradient(
                    colors: enabled
                        ? [Color.mvAccentGradientStart, Color.mvAccentGradientEnd]
                        : [Color.mvAccent.opacity(0.4), Color.mvAccent.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: shape
            )
            .shadow(
                color: enabled ? Color.mvAccent.opacity(0.3) : .clear,
                radius: 14,
                x: 0,
                y: 5
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .clipShape(shape)
            .contentShape(shape)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct MVSecondaryButtonStyle: ButtonStyle {
    var tint: Color = .mvAccent

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(tint)
            .background(Color.mvSurface.opacity(0.45), in: shape)
            .overlay {
                shape
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
            .clipShape(shape)
            .contentShape(shape)
    }
}

extension MedicineForm {
    var systemImage: String {
        switch self {
        case .tablet: "pills.fill"
        case .capsule: "capsule.fill"
        case .liquid: "waterbottle.fill"
        case .injection: "syringe.fill"
        case .patch: "cross.case.fill"
        case .inhaler: "lungs.fill"
        case .other: "cross.vial.fill"
        }
    }
}
