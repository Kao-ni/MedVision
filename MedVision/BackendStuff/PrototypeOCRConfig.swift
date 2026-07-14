import Foundation

enum PrototypeOCRConfig {
    static let apiKey = PrototypeOCRSecrets.apiKey
    static let baseURL = URL(string: "https://api.opentyphoon.ai/v1")!
    static let model = "typhoon-ocr"

    static var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
