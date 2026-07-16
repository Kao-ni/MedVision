import SwiftData
import SwiftUI

enum DailyDoseProgressState: String, Equatable {
    case empty
    case half
    case full
}

struct DailyDoseSummary: Equatable {
    let total: Int
    let completed: Int

    var progress: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    var state: DailyDoseProgressState {
        guard total > 0, completed > 0 else { return .empty }
        return completed == total ? .full : .half
    }
}

enum WeeklyDoseTrackerLogic {
    static func mondayWeek(
        containing referenceDate: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let today = calendar.startOfDay(for: referenceDate)
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceMonday = (weekday + 5) % 7
        guard let monday = calendar.date(
            byAdding: .day,
            value: -daysSinceMonday,
            to: today
        ) else { return [] }

        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: monday)
        }
    }

    static func summary(
        for date: Date,
        events: [DoseEvent],
        calendar: Calendar = .current
    ) -> DailyDoseSummary {
        let dayEvents = events.filter { calendar.isDate($0.scheduledTime, inSameDayAs: date) }
        return DailyDoseSummary(
            total: dayEvents.count,
            completed: dayEvents.filter { $0.status == .complete }.count
        )
    }
}

@MainActor
enum DoseEventWindowScheduler {
    static func ensureCurrentWindow(
        medicines: [Medicine],
        in context: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) {
        let today = calendar.startOfDay(for: referenceDate)
        for medicine in medicines {
            insertMissingEvents(
                for: medicine,
                scheduledTimes: medicine.scheduledTimes,
                startingAt: today,
                dayCount: 4,
                in: context,
                calendar: calendar,
                pendingEventsCountAsExisting: true
            )
        }
    }

    static func reconcileCurrentWindow(
        for medicine: Medicine,
        scheduledTimes: [Date],
        in context: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) {
        let today = calendar.startOfDay(for: referenceDate)
        guard let windowEnd = calendar.date(byAdding: .day, value: 4, to: today) else { return }

        medicine.doseEvents
            .filter {
                $0.status == .pending &&
                    $0.scheduledTime >= today &&
                    $0.scheduledTime < windowEnd
            }
            .forEach { context.delete($0) }

        insertMissingEvents(
            for: medicine,
            scheduledTimes: scheduledTimes,
            startingAt: today,
            dayCount: 4,
            in: context,
            calendar: calendar,
            pendingEventsCountAsExisting: false
        )
    }

    private static func insertMissingEvents(
        for medicine: Medicine,
        scheduledTimes: [Date],
        startingAt firstDay: Date,
        dayCount: Int,
        in context: ModelContext,
        calendar: Calendar,
        pendingEventsCountAsExisting: Bool
    ) {
        let scheduledMinutes = Set(scheduledTimes.map {
            let components = calendar.dateComponents([.hour, .minute], from: $0)
            return (components.hour ?? 0) * 60 + (components.minute ?? 0)
        })

        for dayOffset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) else {
                continue
            }

            for minuteOfDay in scheduledMinutes {
                guard let scheduledDate = calendar.date(
                    bySettingHour: minuteOfDay / 60,
                    minute: minuteOfDay % 60,
                    second: 0,
                    of: day
                ) else { continue }

                let exists = medicine.doseEvents.contains {
                    calendar.isDate($0.scheduledTime, inSameDayAs: scheduledDate) &&
                        calendar.component(.hour, from: $0.scheduledTime) == minuteOfDay / 60 &&
                        calendar.component(.minute, from: $0.scheduledTime) == minuteOfDay % 60 &&
                        (pendingEventsCountAsExisting || $0.status != .pending)
                }

                if !exists {
                    context.insert(
                        DoseEvent(
                            scheduledTime: scheduledDate,
                            status: .pending,
                            medicine: medicine
                        )
                    )
                }
            }
        }
    }
}

struct WeeklyDoseStrip: View {
    let dates: [Date]
    @Binding var selectedDate: Date
    let summaries: [Date: DailyDoseSummary]
    let onTapDay: (Date) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    private var calendar: Calendar { .current }

    var body: some View {
        HStack(spacing: 7) {
            ForEach(dates, id: \.self) { date in
                dayButton(for: date)
                    .frame(maxWidth: .infinity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: selectedDate)
    }

    private func dayButton(for date: Date) -> some View {
        let selected = isSelected(date)
        let summary = summary(for: date)
        let isFuture = date > calendar.startOfDay(for: .now)

        return Button {
            selectedDate = calendar.startOfDay(for: date)
            onTapDay(date)
        } label: {
            VStack(spacing: 0) {
                Text(
                    date,
                    format: Date.FormatStyle()
                        .weekday(.abbreviated)
                        .locale(locale)
                )
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? Color.mvOnAccent : Color.mvSubtle)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, 10)

                Spacer(minLength: 4)

                DayStatusCircle(
                    completed: summary.state == .full,
                    dayNumber: calendar.component(.day, from: date)
                )
                .padding(.bottom, 7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 82)
            .background(
                selected
                    ? Color.mvAccent
                    : Color.mvSurface.opacity(0.72),
                in: Capsule()
            )
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        selected ? Color.mvAccentGradientEnd : Color.mvBorder.opacity(0.65),
                        lineWidth: selected ? 1.5 : 1
                    )
            }
            .shadow(
                color: selected ? Color.mvAccent.opacity(0.28) : Color.black.opacity(0.07),
                radius: selected ? 10 : 5,
                x: 0,
                y: selected ? 5 : 2
            )
            .opacity(isFuture ? 0.68 : 1)
            .scaleEffect(selected ? 1.02 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDate(for: date))
        .accessibilityValue(accessibilityProgress(for: summary))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }

    private func summary(for date: Date) -> DailyDoseSummary {
        summaries[calendar.startOfDay(for: date)] ?? DailyDoseSummary(total: 0, completed: 0)
    }

    private func accessibilityDate(for date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .complete, time: .omitted)
                .locale(locale)
        )
    }

    private func accessibilityProgress(for summary: DailyDoseSummary) -> String {
        guard summary.total > 0 else {
            return AppLanguage.localized("No doses scheduled", locale: locale)
        }
        return AppLanguage.localized(
            "day_progress_accessibility_format",
            locale: locale,
            arguments: [summary.completed, summary.total]
        )
    }
}

private struct DayStatusCircle: View {
    let completed: Bool
    let dayNumber: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(completed ? Color(hex: "1F2A37") : Color.white)

            if completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
            } else {
                Text("\(dayNumber)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "1F2A37"))
            }
        }
        .frame(width: 38, height: 38)
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        .accessibilityHidden(true)
    }
}
