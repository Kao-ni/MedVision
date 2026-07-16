import SwiftUI

struct DoseEventRow: View {
    let event: DoseEvent
    var showMedicineName: Bool = true
    @Environment(\.locale) private var locale

    private var color: Color { event.status.color }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: event.status.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                if showMedicineName {
                    Text(event.medicine?.name ?? AppLanguage.localized("Unknown", locale: locale))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.mvInk)
                        .lineLimit(1)
                }
                HStack(spacing: 5) {
                    if let dosage = event.medicine?.dosage, !dosage.isEmpty {
                        Text(dosage)
                        Text("·")
                    }
                    Text(
                        event.scheduledTime,
                        format: Date.FormatStyle(date: .omitted, time: .shortened)
                            .locale(locale)
                    )
                    .monospacedDigit()
                }
                .font(.subheadline)
                .foregroundStyle(Color.mvSubtle)
            }

            Spacer()

            Text(LocalizedStringKey(event.status.localizationKey))
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(color.opacity(0.13), in: Capsule())
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let prefix = showMedicineName ? (event.medicine.map { "\($0.name), " } ?? "") : ""
        let time = event.scheduledTime.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(locale)
        )
        let status = AppLanguage.localized(event.status.localizationKey, locale: locale)
        return AppLanguage.localized(
            "scheduled_accessibility_format",
            locale: locale,
            arguments: [prefix + status + ", ", time]
        )
    }
}
