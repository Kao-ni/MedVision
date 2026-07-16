import SwiftUI

struct DoseEventRow: View {
    let event: DoseEvent
    var showMedicineName: Bool = true
    @Environment(\.locale) private var locale

    private var color: Color { event.status.color }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.status.systemImage)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                if showMedicineName, let name = event.medicine?.name {
                    Text(name).font(.headline)
                }
                Text(
                    event.scheduledTime,
                    format: Date.FormatStyle(date: .abbreviated, time: .shortened)
                        .locale(locale)
                )
                    .font(showMedicineName ? .subheadline : .body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(LocalizedStringKey(event.status.localizationKey))
                .font(.headline)
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
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
