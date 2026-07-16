import SwiftUI
import SwiftData
import Auth

struct TodayView: View {
    @Query(sort: \DoseEvent.scheduledTime) private var allEvents: [DoseEvent]
    @Query private var allMedicines: [Medicine]
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("profile_firstName") private var firstName = ""
    @State private var hasAppeared = false
    @Environment(AuthService.self) private var auth

    private var todayEvents: [DoseEvent] {
        allEvents.filter { Calendar.current.isDateInToday($0.scheduledTime) }
    }

    private var overdue: [DoseEvent] {
        todayEvents.filter { $0.status == .pending && $0.scheduledTime < .now }
    }

    private var upcoming: [DoseEvent] {
        todayEvents.filter { $0.status == .pending && $0.scheduledTime >= .now }
    }

    private var done: [DoseEvent] {
        todayEvents
            .filter { $0.status != .pending }
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    private var takenCount: Int { todayEvents.filter { $0.status == .complete }.count }
    private var totalCount: Int { todayEvents.count }
    private var progress: Double { totalCount > 0 ? Double(takenCount) / Double(totalCount) : 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if todayEvents.isEmpty {
                        emptyState
                    } else {
                        ProgressCard(taken: takenCount, total: totalCount, progress: progress)

                        doseSection(
                            title: "Overdue",
                            systemImage: "exclamationmark.circle.fill",
                            tint: .mvDanger,
                            events: overdue,
                            overdue: true
                        )
                        doseSection(
                            title: "Upcoming",
                            systemImage: "clock.fill",
                            tint: .mvAccent,
                            events: upcoming,
                            overdue: false
                        )
                        doseSection(
                            title: "Done",
                            systemImage: "checkmark.circle.fill",
                            tint: .mvSuccess,
                            events: done,
                            overdue: false
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 10)
            }
            .scrollIndicators(.hidden)
            .mvScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                DoseSyncService.mirrorMissedStatuses(events: Array(allEvents))
                generateTodayEventsIfNeeded()
                await syncTodayToCloud()
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.easeOut(duration: 0.45)) {
                        hasAppeared = true
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(greeting)
                .font(.subheadline)
                .foregroundStyle(Color.mvSubtle)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Today")
                Text(
                    Date.now,
                    format: Date.FormatStyle(date: .abbreviated, time: .omitted)
                        .locale(locale)
                )
            }
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(Color.mvInk)
            .accessibilityElement(children: .combine)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let key: String
        switch hour {
        case 5..<12: key = "Good morning"
        case 12..<18: key = "Good afternoon"
        default: key = "Good evening"
        }
        let localized = AppLanguage.localized(key, locale: locale)
        let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName != "First Name" else { return localized }
        return "\(localized), \(trimmedName)"
    }

    @ViewBuilder
    private func doseSection(
        title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        events: [DoseEvent],
        overdue: Bool
    ) -> some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    MVSectionHeader(title: title, systemImage: systemImage, tint: tint)
                    Spacer()
                    Text("\(events.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tint.opacity(0.13), in: Capsule())
                }

                ForEach(events) { event in
                    TodayDoseCard(event: event, isOverdue: overdue)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            MVEmptyState(
                systemImage: "moon.zzz.fill",
                title: "Nothing Scheduled",
                message: "Add medicines and their schedule in the Medicines tab."
            )
            Label("Add medicines from the Medicines tab", systemImage: "arrow.down")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.mvAccent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .glassCard()
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

    private func syncTodayToCloud() async {
        guard !auth.isGuest else { return }
        let token = auth.session?.accessToken
        await DoseSyncService.syncEvents(todayEvents, accessToken: token)
    }

}

private struct ProgressCard: View {
    let taken: Int
    let total: Int
    let progress: Double
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var allDone: Bool { total > 0 && taken == total }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(
                        allDone
                            ? AppLanguage.localized("All done!", locale: locale)
                            : AppLanguage.localized(
                                "progress_taken_format",
                                locale: locale,
                                arguments: [taken, total]
                            )
                    )
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.mvInk)

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
                    .foregroundStyle(Color.mvSubtle)
                }

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .stroke(Color.mvBorder.opacity(0.45), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            allDone ? Color.mvSuccess : Color.mvAccent,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: progress)
                    Text("\(Int(progress * 100))%")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.mvInk)
                }
                .frame(width: 64, height: 64)
                .accessibilityLabel(Text("Daily progress"))
                .accessibilityValue(
                    AppLanguage.localized(
                        "percent_format",
                        locale: locale,
                        arguments: [Int(progress * 100)]
                    )
                )
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.mvBorder.opacity(0.35))
                    Capsule()
                        .fill(allDone ? Color.mvSuccess : Color.mvAccent)
                        .frame(width: proxy.size.width * progress)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
        .padding(18)
        .glassCard()
    }
}

private struct TodayDoseCard: View {
    let event: DoseEvent
    let isOverdue: Bool
    @Environment(\.locale) private var locale
    @Environment(AuthService.self) private var auth

    var body: some View {
        VStack(spacing: 13) {
            HStack(spacing: 13) {
                MVMedicineThumbnail(
                    photoData: event.medicine?.photoData,
                    form: event.medicine?.form ?? .other,
                    size: 46
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.medicine?.name ?? AppLanguage.localized("Unknown", locale: locale))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.mvInk)
                        .lineLimit(1)

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
                    .foregroundStyle(isOverdue ? Color.mvDanger : Color.mvSubtle)
                }

                Spacer()

                if event.status == .pending {
                    Image(systemName: "circle")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(isOverdue ? Color.mvDanger : Color.mvBorder)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: event.status.systemImage)
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(event.status.color)
                        .accessibilityHidden(true)
                }
            }

            if event.status == .pending {
                HStack(spacing: 10) {
                    Button {
                        event.status = .omitted
                        event.takenTime = nil
                        Task { await syncDose() }
                    } label: {
                        Text("Skip")
                    }
                    .buttonStyle(MVSecondaryButtonStyle(tint: .mvSubtle))

                    Button {
                        event.status = .complete
                        event.takenTime = Date()
                        Task { await syncDose() }
                    } label: {
                        Label("Take Now", systemImage: "checkmark")
                    }
                    .buttonStyle(MVSecondaryButtonStyle(tint: isOverdue ? .mvDanger : .mvSuccess))
                }
            } else {
                HStack {
                    MVStatusBadge(
                        title: LocalizedStringKey(event.status.localizationKey),
                        systemImage: event.status.systemImage,
                        tint: event.status.color
                    )
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
                        .foregroundStyle(Color.mvSubtle)
                    }
                    Spacer()
                    Button {
                        event.status = .pending
                        event.takenTime = nil
                        Task { await syncDose() }
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .labelStyle(.iconOnly)
                            .frame(width: 36, height: 36)
                    }
                    .foregroundStyle(Color.mvAccent)
                    .accessibilityLabel("Undo")
                }
            }
        }
        .padding(15)
        .glassCard()
        .accessibilityElement(children: .contain)
    }

    private func syncDose() async {
        guard !auth.isGuest else { return }
        await DoseSyncService.syncEvent(event, accessToken: auth.session?.accessToken)
    }
}

#Preview {
    TodayView()
        .environment(AuthService())
        .modelContainer(for: [Medicine.self, DoseEvent.self], inMemory: true)
}
