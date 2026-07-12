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
    // Stable UUID used to generate unique notification identifiers.
    var id: UUID

    var name: String
    var dosage: String
    var form: MedicineForm
    var notes: String
    var photoData: Data?

    var scheduledTimes: [Date]
    var frequencyNote: String

    @Relationship(deleteRule: .cascade, inverse: \DoseEvent.medicine)
    var doseEvents: [DoseEvent] = []

    init(
        id: UUID = UUID(),
        name: String,
        dosage: String = "",
        form: MedicineForm = .pill,
        notes: String = "",
        photoData: Data? = nil,
        scheduledTimes: [Date] = [],
        frequencyNote: String = ""
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.form = form
        self.notes = notes
        self.photoData = photoData
        self.scheduledTimes = scheduledTimes
        self.frequencyNote = frequencyNote
    }
}
