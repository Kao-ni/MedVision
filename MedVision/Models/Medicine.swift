import SwiftData
import Foundation

enum MedicineForm: String, CaseIterable, Codable {
    case pill      = "Pill"
    case liquid    = "Liquid"
    case injection = "Injection"
    case patch     = "Patch"
    case inhaler   = "Inhaler"
    case other     = "Other"
}

@Model
class Medicine {
    var name: String
    var dosage: String
    var form: MedicineForm
    var notes: String
    var photoData: Data?

    // Schedule
    var scheduledTimes: [Date]  // times of day to take this medicine
    var frequencyNote: String   // e.g. "with food", "every 8 hours"

    @Relationship(deleteRule: .cascade, inverse: \DoseEvent.medicine)
    var doseEvents: [DoseEvent] = []

    init(
        name: String,
        dosage: String = "",
        form: MedicineForm = .pill,
        notes: String = "",
        photoData: Data? = nil,
        scheduledTimes: [Date] = [],
        frequencyNote: String = ""
    ) {
        self.name = name
        self.dosage = dosage
        self.form = form
        self.notes = notes
        self.photoData = photoData
        self.scheduledTimes = scheduledTimes
        self.frequencyNote = frequencyNote
    }
}
