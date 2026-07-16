import SwiftUI
import SwiftData
import Auth

private extension TodayTimePeriod {
    var title: LocalizedStringKey {
        switch self {
        case .morning: "Morning"
        case .lunch: "Lunch"
        case .afternoon: "Afternoon"
        case .dinner: "Dinner"
        case .night: "Night"
        }
    }

    var systemImage: String {
        switch self {
        case .morning: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .afternoon: "cloud.sun.fill"
        case .dinner: "sunset.fill"
        case .night: "moon.stars.fill"
        }
    }

    var tint: Color {
        switch self {
        case .morning, .dinner: .mvWarning
        case .lunch, .night: .mvAccent
        case .afternoon: .mvSuccess
        }
    }
}

struct TodayView: View {
    @Query(sort: \DoseEvent.scheduledTime) private var allEvents: [DoseEvent]
    @Query private var allMedicines: [Medicine]
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("profile_firstName") private var firstName = ""
    @AppStorage(UserMealTimes.breakfastKey) private var breakfastSeconds = UserMealTimes.defaultBreakfast
    @AppStorage(UserMealTimes.lunchKey) private var lunchSeconds = UserMealTimes.defaultLunch
    @AppStorage(UserMealTimes.dinnerKey) private var dinnerSeconds = UserMealTimes.defaultDinner
    @State private var hasAppeared = false
    @Environment(AuthService.self) private var auth
    private let runsStartupTasks: Bool
    private let previewMealTimes: UserMealTimes?

    init(
        runsStartupTasks: Bool = true,
        previewMealTimes: UserMealTimes? = nil
    ) {
        self.runsStartupTasks = runsStartupTasks
        self.previewMealTimes = previewMealTimes
    }

    private var todayEvents: [DoseEvent] {
        allEvents.filter { Calendar.current.isDateInToday($0.scheduledTime) }
    }

    private var eventsByPeriod: [TodayTimePeriod: [DoseEvent]] {
        let mealTimes = previewMealTimes ?? UserMealTimes(
            breakfastSeconds: breakfastSeconds,
            lunchSeconds: lunchSeconds,
            dinnerSeconds: dinnerSeconds
        )
        let classifier = TodayPeriodClassifier(
            breakfastSeconds: mealTimes.breakfastSeconds,
            lunchSeconds: mealTimes.lunchSeconds,
            dinnerSeconds: mealTimes.dinnerSeconds
        )
        return Dictionary(
            grouping: todayEvents.sorted { $0.scheduledTime < $1.scheduledTime },
            by: { classifier.period(for: $0.scheduledTime) }
        )
    }

    private var takenCount: Int { todayEvents.filter { $0.status == .complete }.count }
    private var totalCount: Int { todayEvents.count }
    private var progress: Double { totalCount > 0 ? Double(takenCount) / Double(totalCount) : 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if !todayEvents.isEmpty {
                        ProgressCard(taken: takenCount, total: totalCount, progress: progress)
                    }

                    ForEach(TodayTimePeriod.allCases) { period in
                        doseSection(
                            period: period,
                            events: eventsByPeriod[period] ?? []
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
                if runsStartupTasks {
                    DoseSyncService.mirrorMissedStatuses(events: Array(allEvents))
                    generateTodayEventsIfNeeded()
                    await syncTodayToCloud()
                }
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
        period: TodayTimePeriod,
        events: [DoseEvent]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MVSectionHeader(
                    title: period.title,
                    systemImage: period.systemImage,
                    tint: period.tint
                )
                Spacer()
                Text("\(events.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(period.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(period.tint.opacity(0.13), in: Capsule())
            }

            if events.isEmpty {
                Label("No doses scheduled", systemImage: "minus.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.mvSubtle)
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
            } else {
                ForEach(events) { event in
                    TodayDoseCard(
                        event: event,
                        isOverdue: event.status == .pending && event.scheduledTime < .now
                    )
                }
            }
        }
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

#Preview("Today — meal periods") {
    TodayView(
        runsStartupTasks: false,
        previewMealTimes: UserMealTimes(
            breakfastSeconds: UserMealTimes.defaultBreakfast,
            lunchSeconds: UserMealTimes.defaultLunch,
            dinnerSeconds: UserMealTimes.defaultDinner
        )
    )
        .environment(AuthService())
        .modelContainer(todayPreviewContainer(populated: true))
}

#Preview("Today — empty, Thai dark") {
    TodayView(
        runsStartupTasks: false,
        previewMealTimes: UserMealTimes(
            breakfastSeconds: UserMealTimes.defaultBreakfast,
            lunchSeconds: UserMealTimes.defaultLunch,
            dinnerSeconds: UserMealTimes.defaultDinner
        )
    )
        .environment(AuthService())
        .environment(\.locale, Locale(identifier: "th"))
        .preferredColorScheme(.dark)
        .modelContainer(todayPreviewContainer(populated: false))
}

#Preview("Today — accessibility text") {
    TodayView(
        runsStartupTasks: false,
        previewMealTimes: UserMealTimes(
            breakfastSeconds: UserMealTimes.defaultBreakfast,
            lunchSeconds: UserMealTimes.defaultLunch,
            dinnerSeconds: UserMealTimes.defaultDinner
        )
    )
        .environment(AuthService())
        .dynamicTypeSize(.accessibility2)
        .modelContainer(todayPreviewContainer(populated: true))
}

@MainActor
private func todayPreviewContainer(populated: Bool) -> ModelContainer {
    let schema = Schema([Medicine.self, DoseEvent.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: configuration)
    guard populated else { return container }

    let medicine = Medicine(name: "Sample dose", dosage: "1 dose")
    container.mainContext.insert(medicine)

    let samples: [(hour: Int, minute: Int, status: DoseStatus)] = [
        (0, 0, .pending),
        (8, 0, .complete),
        (12, 0, .missed),
        (15, 0, .omitted),
        (18, 0, .pending),
        (21, 0, .pending)
    ]

    for sample in samples {
        guard let scheduledTime = Calendar.current.date(
            bySettingHour: sample.hour,
            minute: sample.minute,
            second: 0,
            of: .now
        ) else { continue }
        let event = DoseEvent(
            scheduledTime: scheduledTime,
            status: sample.status,
            medicine: medicine
        )
        if sample.status == .complete {
            event.takenTime = scheduledTime.addingTimeInterval(5 * 60)
        }
        container.mainContext.insert(event)
    }

    try? container.mainContext.save()
    return container
}
