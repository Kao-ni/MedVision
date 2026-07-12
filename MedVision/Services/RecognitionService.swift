import UIKit

// Structured result parsed from the OCR output.
struct RecognizedMedicine {
    var name: String = ""
    var dosage: String = ""
    var form: MedicineForm = .pill
    var notes: String = ""
}

enum RecognitionError: LocalizedError {
    case notConfigured
    case networkError(Error)
    case noTextFound
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "OCR service is not set up yet."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .noTextFound:
            return "No text could be read from the photo."
        case .parsingFailed:
            return "Couldn't extract medicine details from the photo."
        }
    }
}

// Isolated OCR module — all provider-specific code lives here.
// Swap the implementation inside `recognize` without touching any UI.
//
// TODO: Phase 2 — implement the real call:
//   1. POST image to your backend proxy (do NOT bundle the API key in the app).
//   2. Proxy forwards to api.opentyphoon.ai/v1 (OpenAI-compatible endpoint).
//   3. Typhoon returns Markdown/text describing the packet.
//   4. Parse Markdown → RecognizedMedicine (name, dosage, form).
//   See plan.md Phase 2 for full spec.
struct RecognitionService {
    static let shared = RecognitionService()
    private init() {}

    func recognize(_ image: UIImage) async throws -> RecognizedMedicine {
        throw RecognitionError.notConfigured
    }
}
