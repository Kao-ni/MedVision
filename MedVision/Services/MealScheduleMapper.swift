import Foundation

struct UserMealTimes: Equatable {
    var breakfastSeconds: Int
    var lunchSeconds: Int
    var dinnerSeconds: Int

    static let breakfastKey = "meal_breakfastSeconds"
    static let lunchKey = "meal_lunchSeconds"
    static let dinnerKey = "meal_dinnerSeconds"

    static let defaultBreakfast = 8 * 60 * 60
    static let defaultLunch = 12 * 60 * 60
    static let defaultDinner = 18 * 60 * 60

    static func loadFromDefaults(_ defaults: UserDefaults = .standard) -> UserMealTimes {
        UserMealTimes(
            breakfastSeconds: (defaults.object(forKey: breakfastKey) as? Int) ?? defaultBreakfast,
            lunchSeconds: (defaults.object(forKey: lunchKey) as? Int) ?? defaultLunch,
            dinnerSeconds: (defaults.object(forKey: dinnerKey) as? Int) ?? defaultDinner
        )
    }
}

struct MealScheduleSuggestion: Equatable {
    var times: [Date]
    var frequencyNote: String
}

enum MealScheduleMapper {
    static let beforeMealOffsetMinutes = 30
    static let nightOffsetFromDinnerMinutes = 120

    static func suggest(
        hint: MedicineScheduleHint?,
        meals: UserMealTimes,
        calendar: Calendar = .current
    ) -> MealScheduleSuggestion {
        guard let hint else {
            return MealScheduleSuggestion(times: [], frequencyNote: "")
        }

        let note = hint.raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if hint.asNeeded && hint.timeSlots.isEmpty && hint.withFood == nil {
            return MealScheduleSuggestion(times: [], frequencyNote: note)
        }

        guard hint.hasMealLink else {
            return MealScheduleSuggestion(times: [], frequencyNote: note)
        }

        var slots = hint.timeSlots
        if slots.isEmpty, hint.withFood != nil {
            slots = [.morning, .midday, .evening]
        }

        let offsetMinutes = hint.withFood == .before ? -beforeMealOffsetMinutes : 0
        var seen = Set<String>()
        var times: [Date] = []

        for slot in orderedUnique(slots) {
            let base = seconds(for: slot, meals: meals)
            let alarm = normalizedSeconds(base + offsetMinutes * 60)
            let key = timeKey(alarm)
            guard seen.insert(key).inserted else { continue }
            times.append(date(fromSeconds: alarm, calendar: calendar))
        }

        times.sort { lhs, rhs in
            let left = calendar.dateComponents([.hour, .minute], from: lhs)
            let right = calendar.dateComponents([.hour, .minute], from: rhs)
            let leftValue = (left.hour ?? 0) * 60 + (left.minute ?? 0)
            let rightValue = (right.hour ?? 0) * 60 + (right.minute ?? 0)
            return leftValue < rightValue
        }

        return MealScheduleSuggestion(times: times, frequencyNote: note)
    }

    private static func orderedUnique(_ slots: [MealSlot]) -> [MealSlot] {
        let order: [MealSlot] = [.morning, .midday, .evening, .night]
        var result: [MealSlot] = []
        for slot in order where slots.contains(slot) {
            result.append(slot)
        }
        return result
    }

    private static func seconds(for slot: MealSlot, meals: UserMealTimes) -> Int {
        switch slot {
        case .morning:
            return meals.breakfastSeconds
        case .midday:
            return meals.lunchSeconds
        case .evening:
            return meals.dinnerSeconds
        case .night:
            return normalizedSeconds(meals.dinnerSeconds + nightOffsetFromDinnerMinutes * 60)
        }
    }

    private static func normalizedSeconds(_ value: Int) -> Int {
        let day = 24 * 60 * 60
        let mod = value % day
        return mod >= 0 ? mod : mod + day
    }

    private static func timeKey(_ seconds: Int) -> String {
        let hour = seconds / 3600
        let minute = (seconds % 3600) / 60
        return "\(hour):\(minute)"
    }

    private static func date(fromSeconds seconds: Int, calendar: Calendar) -> Date {
        var comps = DateComponents()
        comps.hour = seconds / 3600
        comps.minute = (seconds % 3600) / 60
        return calendar.date(from: comps) ?? Date()
    }
}
