import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \DoseEvent.scheduledTime) private var allEvents: [DoseEvent]
    @Query private var allMedicines: [Medicine]
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale

    private var todayEvents: [DoseEvent] {
        allEvents.filter { Calendar.current.isDateInToday($0.scheduledTime) }
    }

    private var overdue: [DoseEvent]  { todayEvents.filter { $0.status == .pending && $0.scheduledTime < .now } }
    private var upcoming: [DoseEvent] { todayEvents.filter { $0.status == .pending && $0.scheduledTime >= .now } }
    private var done: [DoseEvent]     { todayEvents.filter { $0.status != .pending }.sorted { $0.scheduledTime < $1.scheduledTime } }

    private var takenCount: Int  { todayEvents.filter { $0.status == .complete }.count }
    private var totalCount: Int  { todayEvents.count }
    private var progress: Double { totalCount > 0 ? Double(takenCount) / Double(totalCount) : 0 }

    var body: some View {
        NavigationStack {
            Group {
                if todayEvents.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Today")
            .task { generateTodayEventsIfNeeded() }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Today")
                            .font(.headline)
                        Text(
                            Date.now,
                            format: Date.FormatStyle(date: .abbreviated, time: .omitted)
                                .locale(locale)
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ProgressCard(taken: takenCount, total: totalCount, progress: progress)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            if !overdue.isEmpty {
                Section {
                    ForEach(overdue) { event in
                        TodayDoseRow(event: event, isOverdue: true)
                    }
                } header: {
                    Label("Overdue", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            if !upcoming.isEmpty {
                Section {
                    ForEach(upcoming) { event in
                        TodayDoseRow(event: event, isOverdue: false)
                    }
                } header: {
                    Label {
                        Text("Upcoming — \(upcoming.count)")
                    } icon: {
                        Image(systemName: "clock")
                    }
                }
            }

            if !done.isEmpty {
                Section {
                    ForEach(done) { event in
                        TodayDoseRow(event: event, isOverdue: false)
                    }
                } header: {
                    Label {
                        Text("Done — \(done.count)")
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func generateTodayEventsIfNeeded() {
        let calendar = Calendar.current
        for medicine in allMedicines {
            for time in medicine.scheduledTimes {
                let comps = calendar.dateComponents([.hour, .minute], from: time)
                guard let scheduled = calendar.date(
                    bySettingHour: comps.hour ?? 0,
                    minute: comps.minute ?? 0,
                    second: 0,
                    of: Date()
                ) else { continue }

                let exists = medicine.doseEvents.contains {
                    calendar.isDateInToday($0.scheduledTime) &&
                    calendar.component(.hour, from: $0.scheduledTime) == comps.hour &&
                    calendar.component(.minute, from: $0.scheduledTime) == comps.minute
                }

                if !exists {
                    context.insert(DoseEvent(scheduledTime: scheduled, status: .pending, medicine: medicine))
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing Scheduled", systemImage: "moon.zzz")
        } description: {
            Text("Add medicines and their schedule in the Medicines tab.")
        }
    }
}

// MARK: - Progress Card

private struct ProgressCard: View {
    let taken: Int
    let total: Int
    let progress: Double
    @Environment(\.locale) private var locale

    private var allDone: Bool { taken == total }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        allDone
                            ? AppLanguage.localized("All done!", locale: locale)
                            : AppLanguage.localized(
                                "progress_taken_format",
                                locale: locale,
                                arguments: [taken, total]
                            )
                    )
                        .font(.headline)
                    Text(
                        allDone
                            ? AppLanguage.localized("Great job keeping up with your medicines.", locale: locale)
                            : AppLanguage.localized(
                                "progress_remaining_format",
                                locale: locale,
                                arguments: [total - taken]
                            )
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(.systemFill), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(allDone ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.4), value: progress)
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .frame(width: 52, height: 52)
            }

            ProgressView(value: progress)
                .tint(allDone ? .green : .blue)
                .animation(.easeOut(duration: 0.4), value: progress)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Row

struct TodayDoseRow: View {
    let event: DoseEvent
    let isOverdue: Bool
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Group {
                            if let medicineName = event.medicine?.name {
                                Text(verbatim: medicineName)
                            } else {
                                Text("Unknown")
                            }
                        }
                        .font(.title3)
                        .fontWeight(.semibold)

                        if isOverdue {
                            Text("Overdue")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    if let dosage = event.medicine?.dosage, !dosage.isEmpty {
                        Text(dosage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(
                    event.scheduledTime,
                    format: Date.FormatStyle(date: .omitted, time: .shortened)
                        .locale(locale)
                )
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(isOverdue ? .red : .secondary)
            }

            if event.status == .pending {
                HStack(spacing: 10) {
                    Button { event.status = .omitted } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        event.status = .complete
                        event.takenTime = Date()
                    } label: {
                        Label("Take Now", systemImage: "checkmark")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isOverdue ? Color.red : Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack {
                    Label {
                        Text(LocalizedStringKey(event.status.localizationKey))
                    } icon: {
                        Image(systemName: event.status.systemImage)
                    }
                        .font(.subheadline)
                        .foregroundStyle(event.status.color)
                    if let takenTime = event.takenTime, event.status == .complete {
                        Text(
                            AppLanguage.localized(
                                "taken_at_format",
                                locale: locale,
                                arguments: [
                                    takenTime.formatted(
                                        Date.FormatStyle(date: .omitted, time: .shortened)
                                            .locale(locale)
                                    )
                                ]
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if event.status != .pending {
                Button {
                    event.status = .pending
                    event.takenTime = nil
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .tint(.indigo)
            }
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [Medicine.self, DoseEvent.self], inMemory: true)
}
