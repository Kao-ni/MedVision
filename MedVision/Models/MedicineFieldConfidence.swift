import Foundation

enum RecognitionConfidence: String, Equatable {
    case high
    case medium
    case low
}

struct MedicineFieldConfidence: Equatable {
    var name: RecognitionConfidence? = nil
    var dosage: RecognitionConfidence? = nil
    var form: RecognitionConfidence? = nil
    var whenToTake: RecognitionConfidence? = nil

    var hasUncertainFields: Bool {
        [name, dosage, form, whenToTake].contains { $0 == .low || $0 == .medium }
    }
}
