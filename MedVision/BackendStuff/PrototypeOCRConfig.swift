import Foundation

enum PrototypeOCRConfig {
    static let apiKey = "sk-gMl0NyFLGpzIpMF98CEgoy5GHKMuRnJ3vhKv1b80D9JoFnYv"
    static let baseURL = URL(string: "https://api.opentyphoon.ai/v1")!
    static let model = "typhoon-ocr"
    static let parseModel = "typhoon-v2.5-30b-a3b-instruct"

    static var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
