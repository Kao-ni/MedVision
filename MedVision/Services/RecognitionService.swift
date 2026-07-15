import UIKit
import Foundation

// Structured result parsed from the OCR output.
struct RecognizedMedicine {
    var name: String = ""
    var dosage: String = ""
    var form: MedicineForm = .tablet
    var notes: String = ""
    var photoData: Data? = nil
}

enum RecognitionError: LocalizedError {
    case notConfigured
    case invalidImageData
    case imagePreprocessingFailed(String)
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
        case .imagePreprocessingFailed(let message):
            return "Couldn't straighten the photo: \(message)"
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
        let resized = image.resized(toMaxDimension: 1920)
        let corrected: UIImage
        do {
            corrected = try await DewarpService.shared.dewarp(resized)
        } catch {
            throw RecognitionError.imagePreprocessingFailed(error.localizedDescription)
        }
        guard let imageData = corrected.jpegData(compressionQuality: 0.80) else {
            throw RecognitionError.invalidImageData
        }

        // Step 1: Extract raw text from the image using the OCR model.
        let rawText: String
        do {
            rawText = try await performOCR(imageData: imageData)
        } catch let error as RecognitionError {
            throw error
        } catch {
            throw RecognitionError.networkError(error)
        }

        // Step 2: Parse the raw OCR text into structured medicine JSON using a language model.
        let structuredJSON: String
        do {
            structuredJSON = try await structureMedicineData(from: rawText)
        } catch let error as RecognitionError {
            throw error
        } catch {
            throw RecognitionError.networkError(error)
        }

        let parsed = parseRecognizedMedicine(from: structuredJSON, photoData: imageData)
        guard !parsed.name.isEmpty else {
            throw RecognitionError.parsingFailed
        }
        return parsed
    }

    // Sends the image to the OCR model and returns the raw extracted text.
    private func performOCR(imageData: Data) async throws -> String {
        let endpoint = PrototypeOCRConfig.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(PrototypeOCRConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": PrototypeOCRConfig.model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": "Extract and transcribe all text visible in this image. The text may be in Thai, English, or a mix of both. Carefully preserve every Thai character, vowel mark, and tone mark exactly as it appears — do not romanize or transliterate Thai. Return only the extracted text, preserving the original layout."],
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

        let (data, response) = try await URLSession.shared.data(for: request)

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

    // Sends raw OCR text to a language model and returns structured medicine JSON.
    private func structureMedicineData(from rawText: String) async throws -> String {
        let endpoint = PrototypeOCRConfig.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(PrototypeOCRConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let prompt = """
        You are the medicine extraction engine for MedTrack, a personal medication-reminder app.
        You receive raw OCR text from a photo of a medicine packet, blister pack, pharmacy label,
        or leaflet. Convert it into structured fields for the app's confirm-and-edit screen.

        You are a transcription-and-structuring engine, NOT a clinician. You never diagnose,
        never recommend or adjust doses, and never add medical information that is not printed
        on the source text.

        The user ALWAYS reviews and confirms your output before it is saved. Your job is to give
        them the best pre-filled draft possible — and to be honest about what you couldn't read.

        ====================================================================
        INPUT
        ====================================================================
        Raw OCR text. The source label may be in Thai, English, or both — Thai is common
        for pharmacy-dispensed medicine in Thailand. Assume the text is imperfect: character
        errors (e.g. "5Omg" for "50mg"), missing or out-of-order fragments, mixed languages,
        and unrelated text (barcodes, manufacturer address, marketing, price stickers).
        It may not be a medicine at all.

        Correct only obvious OCR artifacts inside values (letter O read as zero in a dose
        number, "rnl" for "ml"). Never "fix" the text into something it doesn't say.

        ====================================================================
        SAFETY RULES (override everything else)
        ====================================================================
        1. NEVER invent or guess a value the text does not support. A missing value is null,
           never a plausible-sounding guess.
        2. Transcribe the dosage EXACTLY as printed. Do not convert units, round, or normalize
           strength into a value the packet does not show.
        3. Do not add dosing advice, indications, or warnings from outside knowledge. Only
           restate what the packaging/leaflet text says.
        4. If the name, dosage, or when-to-take information is unclear, partial, or ambiguous,
           set confidence to "low" for that field and add a warning — do not silently pick one
           interpretation.
        5. Never place personal information (patient name, prescriber, Rx number) into any
           output field. If present in the text, ignore it.

        ====================================================================
        FIELDS TO EXTRACT
        ====================================================================
        - name          The medicine name as printed. Prefer the brand/product name; if only an
                        active ingredient is shown, use that. If both are clearly printed, use
                        "Brand (ingredient)". null if unreadable.

        - dosage        Strength per unit, verbatim from the packet, e.g. "500 mg", "5 mg/ml",
                        "20 mg". null if not printed or unreadable.

        - form          One of: "tablet", "capsule", "liquid", "injection", "drops", "cream",
                        "inhaler", "patch", "powder", "other". Infer from words like "tablets",
                        "syrup", "solution". Also recognize Thai terms: เม็ด/เม็ดฟู้ด/เม็ดฟี้ = pill,
                        แคปซูล = capsule, ยาน้ำ/น้ำเชื่อม/ยาน้ำเชื่อม = liquid,
                        ยาฉีด = injection, ยาหยอด = drops, ยาทา/ครีม = cream,
                        ยาพ่น = inhaler, ยาผง = powder. null if undeterminable.

        - when_to_take  The dosing schedule as stated on the packet/label, normalized into:
                        {
                          "raw":            the schedule text verbatim, or null,
                          "times_per_day":  integer or null,
                          "time_slots":     subset of ["morning","midday","evening","night"]
                                            ONLY when the text implies them, else [],
                          "with_food":      "before" | "with" | "after" | null,
                          "as_needed":      true | false
                        }
                        Normalize common phrasings: "twice daily"/"BID"/"2x a day" ->
                        times_per_day 2; "every 8 hours" -> times_per_day 3; "at bedtime" ->
                        time_slots ["night"]. Do NOT invent clock times or slots the text
                        doesn't imply.
                        Also normalize Thai phrasings:
                          วันละ 1/2/3/4 ครั้ง -> times_per_day 1/2/3/4
                          ทุก 4 ชั่วโมง -> times_per_day 6; ทุก 6 ชั่วโมง -> 4; ทุก 8 ชั่วโมง -> 3; ทุก 12 ชั่วโมง -> 2
                          เช้า -> time_slots ["morning"]; กลางวัน -> ["midday"]; เย็น -> ["evening"]; ก่อนนอน -> ["night"]
                          ก่อนอาหาร -> with_food "before"; หลังอาหาร -> with_food "after"; พร้อมอาหาร -> with_food "with"
                          เมื่อมีอาการ/เมื่อปวด/เมื่อจำเป็น -> as_needed true
                        If no schedule is printed, leave raw null and times_per_day null.

        - notes         Short, useful text taken from the packaging only: key warnings,
                        storage instructions, duration, or expiry if legible. Plain wording,
                        one line per item joined with "; ". null if nothing useful is printed.

        ====================================================================
        CONFIDENCE & WARNINGS
        ====================================================================
        - confidence: per-field "high" | "medium" | "low" for name, dosage, form, when_to_take.
        - warnings: array of short strings for the app to surface on the confirm screen.

        ====================================================================
        EDGE CASES
        ====================================================================
        - Not a medicine: set "is_medicine": false, all fields null, one warning describing the problem.
        - Multiple medicines: extract the most prominent one, add a warning.

        ====================================================================
        OUTPUT
        ====================================================================
        Respond with STRICT JSON ONLY — no markdown, no code fences, no commentary.
        Always include every key. Use null / [] for unknowns.

        {
          "is_medicine": true,
          "name": null,
          "dosage": null,
          "form": null,
          "when_to_take": {
            "raw": null,
            "times_per_day": null,
            "time_slots": [],
            "with_food": null,
            "as_needed": false
          },
          "notes": null,
          "confidence": {
            "name": "low",
            "dosage": "low",
            "form": "low",
            "when_to_take": "low"
          },
          "warnings": []
        }

        ====================================================================
        RAW OCR TEXT TO STRUCTURE
        ====================================================================
        \(rawText)
        """

        let body: [String: Any] = [
            "model": PrototypeOCRConfig.parseModel,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a medicine label reader for a medication reminder app used in Thailand. Labels may be in Thai, English, or both. You are fluent in Thai medical terminology. Follow the user's instructions exactly and respond with strict JSON only."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw RecognitionError.badResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = extractErrorMessage(from: data)
            throw RecognitionError.serviceError(message ?? "Parse request failed with status \(http.statusCode).")
        }
        guard let text = extractMessageContent(from: data)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw RecognitionError.parsingFailed
        }

        return text
    }

    private func parseRecognizedMedicine(from rawText: String, photoData: Data) -> RecognizedMedicine {
        // Strip markdown code fences some models wrap around JSON
        let jsonString = rawText
            .replacingOccurrences(of: #"^```json\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^```\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return RecognizedMedicine(photoData: photoData)
        }

        let name = json["name"] as? String ?? ""
        let dosage = json["dosage"] as? String ?? ""
        let notes = json["notes"] as? String ?? ""
        let formString = json["form"] as? String ?? ""
        let form = mapForm(formString)

        return RecognizedMedicine(
            name: name,
            dosage: dosage,
            form: form,
            notes: notes,
            photoData: photoData
        )
    }

    private func mapForm(_ text: String) -> MedicineForm {
        switch text.lowercased() {
        case "tablet", "pill": return .tablet
        case "capsule": return .capsule
        case "liquid", "syrup", "suspension", "drops": return .liquid
        case "injection": return .injection
        case "patch": return .patch
        case "inhaler": return .inhaler
        default: return .other
        }
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

private extension UIImage {
    func resized(toMaxDimension maxDim: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDim else { return self }
        let scale = maxDim / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
