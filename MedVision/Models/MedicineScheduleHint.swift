import Foundation

enum MealSlot: String, Codable, CaseIterable, Equatable {
    case morning
    case midday
    case evening
    case night
}

enum WithFoodRelation: String, Codable, Equatable {
    case before
    case with
    case after
}

struct MedicineScheduleHint: Equatable {
    var raw: String = ""
    var timesPerDay: Int? = nil
    var timeSlots: [MealSlot] = []
    var withFood: WithFoodRelation? = nil
    var asNeeded: Bool = false

    var hasMealLink: Bool {
        !timeSlots.isEmpty || withFood != nil
    }
}
