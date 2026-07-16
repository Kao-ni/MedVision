import Foundation

enum TodayTimePeriod: Int, CaseIterable, Identifiable {
    case morning
    case lunch
    case afternoon
    case dinner
    case night

    var id: Self { self }
}

struct TodayPeriodClassifier {
    private static let daySeconds = 24 * 60 * 60
    private static let nightOffsetSeconds = 2 * 60 * 60
    private static let defaultBreakfastSeconds = 8 * 60 * 60
    private static let defaultLunchSeconds = 12 * 60 * 60
    private static let defaultDinnerSeconds = 18 * 60 * 60

    private let morningStart: Double
    private let lunchStart: Double
    private let afternoonStart: Double
    private let dinnerStart: Double
    private let nightStart: Double
    private let nextMorningStart: Double

    init(breakfastSeconds: Int, lunchSeconds: Int, dinnerSeconds: Int) {
        let mealTimes: (breakfast: Int, lunch: Int, dinner: Int)
        if Self.areValid(
            breakfast: breakfastSeconds,
            lunch: lunchSeconds,
            dinner: dinnerSeconds
        ) {
            mealTimes = (breakfastSeconds, lunchSeconds, dinnerSeconds)
        } else {
            mealTimes = (
                Self.defaultBreakfastSeconds,
                Self.defaultLunchSeconds,
                Self.defaultDinnerSeconds
            )
        }

        let morningAnchor = Double(mealTimes.breakfast)
        let lunchAnchor = Double(mealTimes.lunch)
        let dinnerAnchor = Double(mealTimes.dinner)
        let afternoonAnchor = (lunchAnchor + dinnerAnchor) / 2
        let nightAnchor = dinnerAnchor + Double(Self.nightOffsetSeconds)
        let previousNightAnchor = nightAnchor - Double(Self.daySeconds)
        let nextMorningAnchor = morningAnchor + Double(Self.daySeconds)

        morningStart = Self.midpoint(previousNightAnchor, morningAnchor)
        lunchStart = Self.midpoint(morningAnchor, lunchAnchor)
        afternoonStart = Self.midpoint(lunchAnchor, afternoonAnchor)
        dinnerStart = Self.midpoint(afternoonAnchor, dinnerAnchor)
        nightStart = Self.midpoint(dinnerAnchor, nightAnchor)
        nextMorningStart = Self.midpoint(nightAnchor, nextMorningAnchor)
    }

    func period(for date: Date, calendar: Calendar = .current) -> TodayTimePeriod {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let seconds = (components.hour ?? 0) * 60 * 60
            + (components.minute ?? 0) * 60
            + (components.second ?? 0)
        return period(forSeconds: seconds)
    }

    func period(forSeconds seconds: Int) -> TodayTimePeriod {
        let day = Self.daySeconds
        let normalized = ((seconds % day) + day) % day
        var adjusted = Double(normalized)

        if adjusted < morningStart {
            adjusted += Double(day)
        }

        if adjusted >= nextMorningStart {
            return .morning
        }
        if adjusted >= nightStart {
            return .night
        }
        if adjusted >= dinnerStart {
            return .dinner
        }
        if adjusted >= afternoonStart {
            return .afternoon
        }
        if adjusted >= lunchStart {
            return .lunch
        }
        return .morning
    }

    private static func areValid(breakfast: Int, lunch: Int, dinner: Int) -> Bool {
        let day = daySeconds
        guard (0..<day).contains(breakfast),
              (0..<day).contains(lunch),
              (0..<day).contains(dinner),
              breakfast < lunch,
              lunch < dinner
        else {
            return false
        }

        // The derived night anchor must still precede the next day's breakfast.
        return dinner + nightOffsetSeconds < breakfast + day
    }

    private static func midpoint(_ lhs: Double, _ rhs: Double) -> Double {
        (lhs + rhs) / 2
    }
}
