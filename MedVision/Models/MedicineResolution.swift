import Foundation

enum ResolutionStatus: String, Equatable {
    case consensus
    case disagreement
    case unverified
}

struct ResolutionCandidate: Equatable, Identifiable {
    var id: String { "\(source)-\(name)" }
    var source: String
    var name: String
    var score: Double?
    var dosage: String?
    var verdict: String?
}

struct MedicineResolution: Equatable {
    var status: ResolutionStatus = .unverified
    var finalName: String? = nil
    var finalDosage: String? = nil
    var label: String? = nil
    var candidates: [ResolutionCandidate] = []
    var judgeSkipped: Bool = false

    var isVerified: Bool { status == .consensus }
    var hasConflict: Bool { status == .disagreement }
}
