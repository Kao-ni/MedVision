import UIKit
import Foundation

// Structured result parsed from the OCR output.
struct RecognizedMedicine {
    var name: String = ""
    var dosage: String = ""
    var form: MedicineForm = .pill
    var notes: String = ""
    var photoData: Data? = nil
}

enum RecognitionError: LocalizedError {
    case notConfigured
    case invalidImageData
    case networkError(Error)
    case badResponse
    case serviceError(String)
    case noTextFound
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Add your Typhoon API key in PrototypeOCRConfig.swift first."
        case .invalidImageData:
            return "Couldn't prepare the photo for OCR."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .badResponse:
            return "The OCR service returned an unreadable response."
        case .serviceError(let message):
            return message
        case .noTextFound:
            return "No text could be read from the photo."
        case .parsingFailed:
            return "Couldn't extract medicine details from the photo."
        }
    }
}

struct RecognitionService {
    static let shared = RecognitionService()
    private init() {}

    func recognize(_ image: UIImage) async throws -> RecognizedMedicine {
        guard PrototypeOCRConfig.isConfigured else {
            throw RecognitionError.notConfigured
        }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw RecognitionError.invalidImageData
        }

        let rawText: String
        do {
            rawText = try await performOCR(imageData: imageData)
        } catch let error as RecognitionError {
            throw error
        } catch {
            throw RecognitionError.networkError(error)
        }

        let parsed = parseRecognizedMedicine(from: rawText, photoData: imageData)
        guard !parsed.name.isEmpty else {
            throw RecognitionError.parsingFailed
        }
        return parsed
    }

    private func performOCR(imageData: Data) async throws -> String {
        let endpoint = PrototypeOCRConfig.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(PrototypeOCRConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let prompt = """
        Read this medicine packet and return plain text with these fields on separate lines:
        Name: <medicine name>
        Dosage: <strength or amount>
        Form: <pill, liquid, injection, patch, inhaler, or other>
        Notes: <short usage note if visible>
        If a field is missing, leave it blank.
        """

        let body: [String: Any] = [
            "model": PrototypeOCRConfig.model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(imageData.base64EncodedString())"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw RecognitionError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw RecognitionError.badResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let message = extractErrorMessage(from: data)
            throw RecognitionError.serviceError(message ?? "OCR request failed with status \(http.statusCode).")
        }

        guard let text = extractMessageContent(from: data)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw RecognitionError.noTextFound
        }

        return text
    }

    private func parseRecognizedMedicine(from rawText: String, photoData: Data) -> RecognizedMedicine {
        let lines = rawText
            .components(separatedBy: .newlines)
            .map { clean($0) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return RecognizedMedicine(photoData: photoData)
        }

        let name = fieldValue(prefix: "name", in: lines) ?? fallbackName(from: lines)
        let dosage = fieldValue(prefix: "dosage", in: lines) ?? extractDosage(from: rawText) ?? ""
        let notes = fieldValue(prefix: "notes", in: lines) ?? ""
        let explicitForm = fieldValue(prefix: "form", in: lines)
        let form = mapForm(explicitForm ?? rawText)

        return RecognizedMedicine(
            name: name,
            dosage: dosage,
            form: form,
            notes: notes,
            photoData: photoData
        )
    }

    private func fieldValue(prefix: String, in lines: [String]) -> String? {
        let normalizedPrefix = prefix.lowercased() + ":"
        for line in lines {
            let lower = line.lowercased()
            guard lower.hasPrefix(normalizedPrefix) else { continue }
            let value = line.dropFirst(normalizedPrefix.count)
            let cleaned = clean(String(value))
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        return nil
    }

    private func fallbackName(from lines: [String]) -> String {
        let first = lines.first ?? ""
        let withoutDose = extractDosage(from: first).map { first.replacingOccurrences(of: $0, with: "") } ?? first
        return clean(withoutDose.replacingOccurrences(of: "tablet", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "tablets", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "capsule", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "capsules", with: "", options: .caseInsensitive))
    }

    private func extractDosage(from text: String) -> String? {
        let pattern = #"\b\d+(?:\.\d+)?\s?(?:mg|mcg|g|ml|iu)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let matchRange = Range(match.range, in: text) else {
            return nil
        }
        return String(text[matchRange])
    }

    private func mapForm(_ text: String) -> MedicineForm {
        let lower = text.lowercased()
        if lower.contains("tablet") || lower.contains("pill") || lower.contains("capsule") || lower.contains("caplet") {
            return .pill
        }
        if lower.contains("liquid") || lower.contains("syrup") || lower.contains("suspension") {
            return .liquid
        }
        if lower.contains("inject") || lower.contains("vial") {
            return .injection
        }
        if lower.contains("patch") {
            return .patch
        }
        if lower.contains("inhaler") || lower.contains("puff") {
            return .inhaler
        }
        return .other
    }

    private func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "- ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractMessageContent(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] else {
            return nil
        }

        if let text = content as? String {
            return text
        }

        if let parts = content as? [[String: Any]] {
            let texts = parts.compactMap { $0["text"] as? String }
            return texts.joined(separator: "\n")
        }

        return nil
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8)
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.isEmpty {
            return message
        }

        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }

        return String(data: data, encoding: .utf8)
    }
}
