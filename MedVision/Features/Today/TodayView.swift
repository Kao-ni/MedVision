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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("profile_firstName") private var firstName = ""
    @AppStorage(UserMealTimes.breakfastKey) private var breakfastSeconds = UserMealTimes.defaultBreakfast
    @AppStorage(UserMealTimes.lunchKey) private var lunchSeconds = UserMealTimes.defaultLunch
    @AppStorage(UserMealTimes.dinnerKey) private var dinnerSeconds = UserMealTimes.defaultDinner
    @State private var hasAppeared = false
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var windowReferenceDate = Date.now
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

    private var trackerDates: [Date] {
        WeeklyDoseTrackerLogic.centeredWeek(containing: windowReferenceDate)
    }

    private var dailySummaries: [Date: DailyDoseSummary] {
        Dictionary(uniqueKeysWithValues: trackerDates.map { date in
            (
                Calendar.current.startOfDay(for: date),
                WeeklyDoseTrackerLogic.summary(for: date, events: Array(allEvents))
            )
        })
    }

    private var selectedEvents: [DoseEvent] {
        allEvents.filter {
            Calendar.current.isDate($0.scheduledTime, inSameDayAs: selectedDate)
        }
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
            grouping: selectedEvents.sorted { $0.scheduledTime < $1.scheduledTime },
            by: { classifier.period(for: $0.scheduledTime) }
        )
    }

    private var takenCount: Int { selectedEvents.filter { $0.status == .complete }.count }
    private var totalCount: Int { selectedEvents.count }
    private var progress: Double { totalCount > 0 ? Double(takenCount) / Double(totalCount) : 0 }
    private var selectedDateIsToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    private var selectedDateIsPast: Bool {
        selectedDate < Calendar.current.startOfDay(for: .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if !selectedEvents.isEmpty {
                        ProgressCard(
                            taken: takenCount,
                            total: totalCount,
                            progress: progress,
                            isToday: selectedDateIsToday
                        )
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
                    DoseEventWindowScheduler.ensureCurrentWindow(
                        medicines: Array(allMedicines),
                        in: context
                    )
                    await NotificationService.shared.refreshExistingRemindersIfNeeded(
                        medicines: Array(allMedicines)
                    )
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
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                refreshDateWindow()
                if runsStartupTasks {
                    DoseSyncService.mirrorMissedStatuses(events: Array(allEvents))
                    DoseEventWindowScheduler.ensureCurrentWindow(
                        medicines: Array(allMedicines),
                        in: context
                    )
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.subheadline)
                .foregroundStyle(Color.mvSubtle)

            Text(selectedDateTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.mvInk)

            WeeklyDoseStrip(
                dates: trackerDates,
                selectedDate: $selectedDate,
                summaries: dailySummaries,
                onTapDay: toggleDayCompletion
            )
            .padding(.top, 8)
        }
    }

    private var selectedDateTitle: String {
        let day = selectedDate.formatted(
            Date.FormatStyle().month(.wide).day().locale(locale)
        )
        if selectedDateIsToday {
            return AppLanguage.localized(
                "today_date_format",
                locale: locale,
                arguments: [day]
            )
        }
        let weekday = selectedDate.formatted(
            Date.FormatStyle().weekday(.wide).locale(locale)
        )
        return AppLanguage.localized(
            "selected_date_format",
            locale: locale,
            arguments: [weekday, day]
        )
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
                Label {
                    Text(
                        selectedDateIsPast
                            ? LocalizedStringKey("No dose records for this day")
                            : LocalizedStringKey("No doses scheduled")
                    )
                } icon: {
                    Image(systemName: "minus.circle")
                }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.mvSubtle)
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
            } else {
                ForEach(events) { event in
                    TodayDoseCard(
                        event: event,
                        isOverdue: event.status == .pending && event.scheduledTime < .now,
                        selectedDate: selectedDate
                    )
                }
            }
        }
    }

    private func refreshDateWindow() {
        let today = Calendar.current.startOfDay(for: .now)
        windowReferenceDate = today
        if !trackerDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) {
            selectedDate = today
        }
    }

    private func toggleDayCompletion(_ date: Date) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: .now)
        guard day <= today else { return }

        let events = allEvents.filter {
            calendar.isDate($0.scheduledTime, inSameDayAs: day)
        }
        guard !events.isEmpty else { return }

        let shouldComplete = !events.allSatisfy { $0.status == .complete }
        for event in events {
            if shouldComplete {
                event.status = .complete
                event.takenTime = calendar.isDateInToday(day) ? .now : event.scheduledTime
            } else {
                event.status = .pending
                event.takenTime = nil
            }
        }

        Task {
            if shouldComplete {
                for event in events {
                    NotificationService.shared.cancelSnooze(for: event)
                }
            }
            await syncDoseEvents(events)
        }
    }

    private func syncTodayToCloud() async {
        guard !auth.isGuest else { return }
        let token = auth.session?.accessToken
        let todayEvents = allEvents.filter { Calendar.current.isDateInToday($0.scheduledTime) }
        await DoseSyncService.syncEvents(todayEvents, accessToken: token)
    }

    private func syncDoseEvents(_ events: [DoseEvent]) async {
        guard !auth.isGuest else { return }
        await DoseSyncService.syncEvents(events, accessToken: auth.session?.accessToken)
    }

}

private struct ProgressCard: View {
    let taken: Int
    let total: Int
    let progress: Double
    let isToday: Bool
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
                                isToday ? "progress_taken_format" : "progress_taken_day_format",
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

private struct DosePrimaryActionStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        configuration.label
            .font(.system(size: 16, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(Color.white)
            .background(tint, in: shape)
            .shadow(
                color: tint.opacity(0.2),
                radius: 7,
                x: 0,
                y: 3
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
            .contentShape(shape)
    }
}

private struct TodayDoseCard: View {
    let event: DoseEvent
    let isOverdue: Bool
    let selectedDate: Date
    @Environment(\.locale) private var locale
    @Environment(AuthService.self) private var auth
    @State private var showTakenTimePicker = false
    @State private var draftTakenTime = Date.now
    @State private var snoozeConfirmation: String?
    @State private var snoozeErrorMessage = ""
    @State private var showSnoozeError = false

    private var calendar: Calendar { .current }
    private var selectedDayStart: Date { calendar.startOfDay(for: selectedDate) }
    private var todayStart: Date { calendar.startOfDay(for: .now) }
    private var isFutureDay: Bool { selectedDayStart > todayStart }
    private var isPastDay: Bool { selectedDayStart < todayStart }
    private var canSnooze: Bool {
        !isPastDay &&
            !isFutureDay &&
            (event.status == .pending || event.status == .missed)
    }

    private var takenTimeRange: ClosedRange<Date> {
        let end = calendar.date(byAdding: .day, value: 1, to: selectedDayStart)?
            .addingTimeInterval(-1) ?? selectedDayStart
        return selectedDayStart...end
    }

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

            if isFutureDay {
                HStack {
                    MVStatusBadge(
                        title: "Upcoming",
                        systemImage: "clock",
                        tint: .mvAccent
                    )
                    Spacer()
                    Text("Future doses can be updated on their scheduled day.")
                        .font(.caption)
                        .foregroundStyle(Color.mvSubtle)
                        .multilineTextAlignment(.trailing)
                }
            } else if event.status == .complete || event.status == .omitted {
                resolvedStatusRow
            } else {
                actionButtons
            }
        }
        .padding(15)
        .glassCard()
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showTakenTimePicker) {
            pastTakenTimeSheet
                .presentationDetents([.medium])
        }
        .alert("Couldn't schedule reminder", isPresented: $showSnoozeError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(snoozeErrorMessage)
        }
    }

    private var resolvedStatusRow: some View {
        HStack {
            MVStatusBadge(
                title: LocalizedStringKey(event.status.localizationKey),
                systemImage: event.status.systemImage,
                tint: event.status.color
            )
            if event.status == .complete, let takenTime = event.takenTime {
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
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.mvAccent.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.mvAccent)
        }
    }

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button {
                markTaken()
            } label: {
                Label {
                    Text(isPastDay ? LocalizedStringKey("Mark Taken") : LocalizedStringKey("Take Now"))
                } icon: {
                    Image(systemName: "checkmark")
                }
            }
            .buttonStyle(
                DosePrimaryActionStyle(tint: isOverdue ? .mvDanger : .mvSuccess)
            )

            HStack(spacing: 0) {
                if canSnooze {
                    compactAction(
                        "Snooze 10 min",
                        systemImage: "clock.arrow.circlepath",
                        tint: .mvAccent,
                        action: snoozeDose
                    )
                    .accessibilityHint("Schedules another reminder in 10 minutes")

                    Divider()
                        .frame(height: 18)
                        .overlay(Color.mvBorder.opacity(0.65))
                }

                compactAction(
                    "Skip",
                    systemImage: "forward.end.fill",
                    tint: .mvSubtle
                ) {
                    snoozeConfirmation = nil
                    event.status = .omitted
                    event.takenTime = nil
                    Task { await cancelSnoozeAndSync() }
                }
            }
            .padding(.horizontal, 4)

            if let snoozeConfirmation {
                Label(snoozeConfirmation, systemImage: "bell.badge.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mvAccent)
                    .accessibilityLabel(snoozeConfirmation)
            }
        }
    }

    private func compactAction(
        _ title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var pastTakenTimeSheet: some View {
        NavigationStack {
            Form {
                DatePicker(
                    "Taken time",
                    selection: $draftTakenTime,
                    in: takenTimeRange,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
            }
            .scrollContentBackground(.hidden)
            .mvScreenBackground()
            .navigationTitle("When was it taken?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTakenTimePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        event.status = .complete
                        event.takenTime = draftTakenTime
                        showTakenTimePicker = false
                        snoozeConfirmation = nil
                        Task { await cancelSnoozeAndSync() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func markTaken() {
        if isPastDay {
            let preferred = event.takenTime ?? event.scheduledTime
            draftTakenTime = min(max(preferred, takenTimeRange.lowerBound), takenTimeRange.upperBound)
            showTakenTimePicker = true
        } else {
            event.status = .complete
            event.takenTime = .now
            snoozeConfirmation = nil
            Task { await cancelSnoozeAndSync() }
        }
    }

    private func snoozeDose() {
        Task {
            switch await NotificationService.shared.snooze(event) {
            case .scheduled(let date):
                let time = date.formatted(
                    Date.FormatStyle(date: .omitted, time: .shortened)
                        .locale(locale)
                )
                snoozeConfirmation = AppLanguage.localized(
                    "snooze_set_format",
                    locale: locale,
                    arguments: [time]
                )
            case .notificationsDisabled:
                snoozeErrorMessage = AppLanguage.localized(
                    "Notifications are disabled. Enable them in Settings to snooze a dose.",
                    locale: locale
                )
                showSnoozeError = true
            case .failed:
                snoozeErrorMessage = AppLanguage.localized(
                    "The reminder couldn't be scheduled. Please try again.",
                    locale: locale
                )
                showSnoozeError = true
            }
        }
    }

    private func cancelSnoozeAndSync() async {
        NotificationService.shared.cancelSnooze(for: event)
        await syncDose()
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
