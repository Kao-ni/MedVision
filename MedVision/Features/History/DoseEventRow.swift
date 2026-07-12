import SwiftUI

struct DoseEventRow: View {
    let event: DoseEvent
    var showMedicineName: Bool = true

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
                Text(event.scheduledTime.formatted(date: .abbreviated, time: .shortened))
                    .font(showMedicineName ? .subheadline : .body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(event.status.displayName)
                .font(.headline)
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let prefix = showMedicineName ? (event.medicine.map { "\($0.name), " } ?? "") : ""
        let time = event.scheduledTime.formatted(date: .abbreviated, time: .shortened)
        return "\(prefix)\(event.status.displayName), scheduled \(time)"
    }
}
