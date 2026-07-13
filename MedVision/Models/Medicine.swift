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
    // Stable per-medicine tag used to group notification identifiers.
    // Intentionally NOT named "id" to avoid conflicting with @Model's
    // synthesised Identifiable conformance (id: PersistentIdentifier).
    var notificationTag: String

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
        name: String,
        dosage: String = "",
        form: MedicineForm = .pill,
        notes: String = "",
        photoData: Data? = nil,
        scheduledTimes: [Date] = [],
        frequencyNote: String = ""
    ) {
        self.notificationTag = UUID().uuidString
        self.name = name
        self.dosage = dosage
        self.form = form
        self.notes = notes
        self.photoData = photoData
        self.scheduledTimes = scheduledTimes
        self.frequencyNote = frequencyNote
    }
}
