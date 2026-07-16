import UIKit
import Foundation

// Structured result parsed from the OCR output.
struct RecognizedMedicine {
    var name: String = ""
    var dosage: String = ""
    var form: MedicineForm = .tablet
    var notes: String = ""
    var photoData: Data? = nil
    var scheduleHint: MedicineScheduleHint? = nil
    var fieldConfidence: MedicineFieldConfidence = MedicineFieldConfidence()
    var warnings: [String] = []
    var resolution: MedicineResolution? = nil
}

enum RecognitionError: LocalizedError {
    case notConfigured
    case notSignedIn
    case invalidImageData
    case networkError(Error)
    case badResponse
    case serviceError(String)
    case noTextFound
    case notMedicine
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return AppLanguage.localized("Add your Typhoon API key in PrototypeOCRConfig.swift first.")
        case .notSignedIn:
            return AppLanguage.localized("Sign in to scan medicine labels with cloud recognition.")
        case .invalidImageData:
            return AppLanguage.localized("Couldn't prepare the photo for OCR.")
        case .networkError(let e):
            return AppLanguage.localized(
                "network_error_format",
                arguments: [e.localizedDescription]
            )
        case .badResponse:
            return AppLanguage.localized("The OCR service returned an unreadable response.")
        case .serviceError(let message):
            return message
        case .noTextFound:
            return AppLanguage.localized("No text could be read from the photo.")
        case .notMedicine:
            return AppLanguage.localized("This doesn't look like a medicine label. You can enter it manually instead.")
        case .parsingFailed:
            return AppLanguage.localized("Couldn't extract medicine details from the photo.")
        }
    }
}

enum RecognitionStage: Equatable {
    case idle
    case readingLabel
    case checkingLists
    case verifyingDetails

    var message: String {
        switch self {
        case .idle:
            return ""
        case .readingLabel:
            return AppLanguage.localized("Reading label...")
        case .checkingLists:
            return AppLanguage.localized("Checking medicine lists...")
        case .verifyingDetails:
            return AppLanguage.localized("Verifying details...")
        }
    }
}

struct RecognitionService {
    static let shared = RecognitionService()
    private init() {}

    /// Prefer Supabase `recognize-medicine` (consensus pipeline). Falls back to client Typhoon when unsigned / guest.
    func recognize(
        _ image: UIImage,
        accessToken: String? = nil,
        onStage: ((RecognitionStage) -> Void)? = nil
    ) async throws -> RecognizedMedicine {
        let resized = image.resized(toMaxDimension: 1280)
        guard let imageData = resized.jpegData(compressionQuality: 0.80) else {
            throw RecognitionError.invalidImageData
        }

        if SupabaseConfig.isConfigured, let token = accessToken, !token.isEmpty {
            do {
                return try await recognizeViaBackend(
                    imageData: imageData,
                    accessToken: token,
                    onStage: onStage
                )
            } catch {
                // Fall through to client OCR + local consensus when edge function is unreachable.
                if PrototypeOCRConfig.isConfigured {
                    onStage?(.readingLabel)
                    return try await recognizeViaClient(imageData: imageData, onStage: onStage)
                }
                throw error
            }
        }

        guard PrototypeOCRConfig.isConfigured else {
            if SupabaseConfig.isConfigured {
                throw RecognitionError.notSignedIn
            }
            throw RecognitionError.notConfigured
        }

        // Guest / unsigned: client Typhoon OCR + on-device consensus (no Supabase auth required).
        onStage?(.readingLabel)
        return try await recognizeViaClient(imageData: imageData, onStage: onStage)
    }

    private func recognizeViaBackend(
        imageData: Data,
        accessToken: String,
        onStage: ((RecognitionStage) -> Void)?
    ) async throws -> RecognizedMedicine {
        onStage?(.readingLabel)

        let endpoint = SupabaseConfig.projectURL
            .appendingPathComponent("functions/v1/recognize-medicine")

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 180

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"medicine.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        onStage?(.checkingLists)
        onStage?(.verifyingDetails)

        let (data, response): (Data, URLResponse)
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
            throw RecognitionError.serviceError(
                message ?? AppLanguage.localized(
                    "ocr_status_error_format",
                    arguments: [http.statusCode]
                )
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RecognitionError.badResponse
        }

        return try mapBackendResponse(json, photoData: imageData)
    }

    private func mapBackendResponse(_ json: [String: Any], photoData: Data) throws -> RecognizedMedicine {
        guard let parsed = json["parsedMedicine"] as? [String: Any] else {
            throw RecognitionError.parsingFailed
        }

        let isMedicine = parsed["is_medicine"] as? Bool ?? true
        if isMedicine == false {
            throw RecognitionError.notMedicine
        }

        let name = stringValue(parsed["name"])
        guard !name.isEmpty else {
            throw RecognitionError.parsingFailed
        }

        let dosage = stringValue(parsed["dosage"])
        let notes = stringValue(parsed["notes"])
        let form = mapForm(stringValue(parsed["form"]))
        let warnings = (parsed["warnings"] as? [String]) ?? []
        let resolution = parseResolution(from: json["resolution"] as? [String: Any], judgeSkipped: json["judgeSkipped"] as? Bool ?? false)

        var result = RecognizedMedicine(
            name: name,
            dosage: dosage,
            form: form,
            notes: notes,
            photoData: photoData,
            scheduleHint: nil,
            fieldConfidence: MedicineFieldConfidence(),
            warnings: warnings,
            resolution: resolution
        )

        // Apply consensus prefill for name/dosage when verified.
        if let resolution, resolution.status == .consensus {
            if let finalName = resolution.finalName, !finalName.isEmpty {
                result.name = finalName
            }
            if let finalDosage = resolution.finalDosage, !finalDosage.isEmpty {
                result.dosage = finalDosage
            }
        } else if let resolution, resolution.status == .unverified {
            if let finalName = resolution.finalName, !finalName.isEmpty {
                result.name = finalName
            }
        }

        return result
    }

    private func parseResolution(from json: [String: Any]?, judgeSkipped: Bool) -> MedicineResolution? {
        guard let json else { return nil }
        let statusRaw = stringValue(json["status"]).lowercased()
        let status = ResolutionStatus(rawValue: statusRaw) ?? .unverified

        let candidatesJSON = json["candidates"] as? [[String: Any]] ?? []
        let candidates: [ResolutionCandidate] = candidatesJSON.compactMap { entry in
            let name = stringValue(entry["name"])
            guard !name.isEmpty else { return nil }
            let score: Double?
            if let number = entry["score"] as? Double {
                score = number
            } else if let number = entry["score"] as? NSNumber {
                score = number.doubleValue
            } else {
                score = nil
            }
            return ResolutionCandidate(
                source: stringValue(entry["source"]),
                name: name,
                score: score,
                dosage: {
                    let value = stringValue(entry["dosage"])
                    return value.isEmpty ? nil : value
                }(),
                verdict: {
                    let value = stringValue(entry["verdict"])
                    return value.isEmpty ? nil : value
                }()
            )
        }

        let finalName = stringValue(json["finalName"])
        let finalDosage = stringValue(json["finalDosage"])

        return MedicineResolution(
            status: status,
            finalName: finalName.isEmpty ? nil : finalName,
            finalDosage: finalDosage.isEmpty ? nil : finalDosage,
            label: {
                let value = stringValue(json["label"])
                return value.isEmpty ? nil : value
            }(),
            candidates: candidates,
            judgeSkipped: judgeSkipped
        )
    }

    private func recognizeViaClient(
        imageData: Data,
        onStage: ((RecognitionStage) -> Void)? = nil
    ) async throws -> RecognizedMedicine {
        let rawText: String
        do {
            rawText = try await performOCR(imageData: imageData)
        } catch let error as RecognitionError {
            throw error
        } catch {
            throw RecognitionError.networkError(error)
        }

        let structuredJSON: String
        do {
            structuredJSON = try await structureMedicineData(from: rawText)
        } catch let error as RecognitionError {
            throw error
        } catch {
            throw RecognitionError.networkError(error)
        }

        var medicine = try parseRecognizedMedicine(from: structuredJSON, photoData: imageData)

        onStage?(.checkingLists)
        onStage?(.verifyingDetails)
        let resolution = await LocalConsensusEngine.run(
            ocrName: medicine.name,
            ocrDosage: medicine.dosage
        ) { thai, openFda in
            return await self.callLocalJudge(
                rawText: rawText,
                medicine: medicine,
                thai: thai,
                openFda: openFda
            )
        }

        medicine.resolution = resolution
        if resolution.status == .consensus {
            if let finalName = resolution.finalName, !finalName.isEmpty {
                medicine.name = finalName
            }
            if let finalDosage = resolution.finalDosage, !finalDosage.isEmpty {
                medicine.dosage = finalDosage
            }
        } else if resolution.status == .unverified {
            if let finalName = resolution.finalName, !finalName.isEmpty {
                medicine.name = finalName
            }
        }

        return medicine
    }

    private func callLocalJudge(
        rawText: String,
        medicine: RecognizedMedicine,
        thai: LocalConsensusEngine.MatchResult?,
        openFda: LocalConsensusEngine.MatchResult?
    ) async -> LocalConsensusEngine.JudgeResult? {
        guard PrototypeOCRConfig.isConfigured else { return nil }

        let endpoint = PrototypeOCRConfig.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(PrototypeOCRConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let prompt = """
        You are a medicine-label arbitrator for a reminder app used in Thailand.
        Decide the best medicine name and fix obvious OCR dosage typos (e.g. 5Omg -> 50mg).
        Do NOT invent a drug unsupported by the OCR or suggestions.
        Return STRICT JSON ONLY:
        {
          "name": string | null,
          "dosage": string | null,
          "verdict": "prefer_thai" | "prefer_openfda" | "prefer_ocr" | "uncertain",
          "notes": string
        }

        RAW OCR:
        \(rawText)

        PARSED:
        name=\(medicine.name), dosage=\(medicine.dosage), form=\(medicine.form.rawValue)

        THAI LIST:
        \(thai.map { "\($0.name) score=\($0.score)" } ?? "null")

        OPENFDA:
        \(openFda.map { "\($0.name) score=\($0.score)" } ?? "null")
        """

        let body: [String: Any] = [
            "model": PrototypeOCRConfig.parseModel,
            "max_tokens": 300,
            "messages": [
                [
                    "role": "system",
                    "content": "You arbitrate medicine name candidates. Return strict JSON only."
                ],
                ["role": "user", "content": prompt]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let text = extractMessageContent(from: data)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return LocalConsensusEngine.JudgeResult(name: nil, dosage: nil, verdict: "uncertain")
            }

            let cleaned = text
                .replacingOccurrences(of: #"^```json\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"^```\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let jsonData = cleaned.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return LocalConsensusEngine.JudgeResult(name: nil, dosage: nil, verdict: "uncertain")
            }

            let name = (json["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let dosage = (json["dosage"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let verdict = (json["verdict"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "uncertain"

            return LocalConsensusEngine.JudgeResult(
                name: (name?.isEmpty == false) ? name : nil,
                dosage: (dosage?.isEmpty == false) ? dosage : nil,
                verdict: verdict
            )
        } catch {
            return LocalConsensusEngine.JudgeResult(name: nil, dosage: nil, verdict: "uncertain")
        }
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
            throw RecognitionError.serviceError(
                message ?? AppLanguage.localized(
                    "ocr_status_error_format",
                    arguments: [http.statusCode]
                )
            )
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
            "max_tokens": 600,
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
            throw RecognitionError.serviceError(
                message ?? AppLanguage.localized(
                    "parse_status_error_format",
                    arguments: [http.statusCode]
                )
            )
        }
        guard let text = extractMessageContent(from: data)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            throw RecognitionError.parsingFailed
        }

        return text
    }

    private func parseRecognizedMedicine(from rawText: String, photoData: Data) throws -> RecognizedMedicine {
        // Strip markdown code fences some models wrap around JSON
        let jsonString = rawText
            .replacingOccurrences(of: #"^```json\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^```\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return try parseStructuredMedicine(from: json, photoData: photoData)
        }

        throw RecognitionError.parsingFailed
    }

    private func parseStructuredMedicine(from json: [String: Any], photoData: Data) throws -> RecognizedMedicine {
        let isMedicine = json["is_medicine"] as? Bool ?? true
        guard isMedicine else {
            throw RecognitionError.notMedicine
        }

        let name = firstString(
            from: json,
            keys: ["name", "medicine_name", "brand_name", "product_name"]
        )
        guard !name.isEmpty else {
            throw RecognitionError.parsingFailed
        }

        let dosage = firstString(
            from: json,
            keys: ["dosage", "strength", "dose", "dose_strength"]
        )
        let notes = firstString(
            from: json,
            keys: ["notes", "warning", "frequency_note", "frequencyNote"]
        )
        let form = mapForm(firstString(from: json, keys: ["form", "dosage_form", "route"]))
        let scheduleHint = parseScheduleHint(from: json)
        let fieldConfidence = parseFieldConfidence(from: json)
        let warnings = parseWarnings(from: json)

        return RecognizedMedicine(
            name: name,
            dosage: dosage,
            form: form,
            notes: notes,
            photoData: photoData,
            scheduleHint: scheduleHint,
            fieldConfidence: fieldConfidence,
            warnings: warnings,
            resolution: nil
        )
    }

    private func parseFieldConfidence(from json: [String: Any]) -> MedicineFieldConfidence {
        guard let confidence = json["confidence"] as? [String: Any] else {
            return MedicineFieldConfidence()
        }

        return MedicineFieldConfidence(
            name: parseConfidence(confidence["name"]),
            dosage: parseConfidence(confidence["dosage"]),
            form: parseConfidence(confidence["form"]),
            whenToTake: parseConfidence(confidence["when_to_take"])
        )
    }

    private func parseConfidence(_ value: Any?) -> RecognitionConfidence? {
        guard let string = value as? String else { return nil }
        return RecognitionConfidence(rawValue: string.lowercased())
    }

    private func parseWarnings(from json: [String: Any]) -> [String] {
        if let warnings = json["warnings"] as? [String] {
            return warnings
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        let singleWarning = stringValue(json["warning"])
        return singleWarning.isEmpty ? [] : [singleWarning]
    }

    private func parseScheduleHint(from json: [String: Any]) -> MedicineScheduleHint? {
        let containerKeys = ["medicine", "parsed", "result", "data", "payload", "fields"]

        var whenToTake = json["when_to_take"] as? [String: Any]
        if whenToTake == nil {
            for containerKey in containerKeys {
                if let nested = json[containerKey] as? [String: Any],
                   let nestedWhen = nested["when_to_take"] as? [String: Any] {
                    whenToTake = nestedWhen
                    break
                }
            }
        }

        guard let whenToTake else { return nil }

        let raw = stringValue(whenToTake["raw"])
        let timesPerDay: Int?
        if let number = whenToTake["times_per_day"] as? Int {
            timesPerDay = number
        } else if let number = whenToTake["times_per_day"] as? NSNumber {
            timesPerDay = number.intValue
        } else {
            timesPerDay = nil
        }

        let slotStrings = whenToTake["time_slots"] as? [String] ?? []
        let timeSlots = slotStrings.compactMap { MealSlot(rawValue: $0.lowercased()) }

        let withFoodRaw = stringValue(whenToTake["with_food"]).lowercased()
        let withFood: WithFoodRelation? = withFoodRaw.isEmpty
            ? nil
            : WithFoodRelation(rawValue: withFoodRaw)

        let asNeeded = whenToTake["as_needed"] as? Bool ?? false

        let hint = MedicineScheduleHint(
            raw: raw,
            timesPerDay: timesPerDay,
            timeSlots: timeSlots,
            withFood: withFood,
            asNeeded: asNeeded
        )

        if hint.raw.isEmpty
            && hint.timesPerDay == nil
            && hint.timeSlots.isEmpty
            && hint.withFood == nil
            && !hint.asNeeded {
            return nil
        }

        return hint
    }

    private func stringValue(_ value: Any?) -> String {
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return ""
    }

    private func firstString(from json: [String: Any], keys: [String]) -> String {
        let containerKeys = ["medicine", "parsed", "result", "data", "payload", "fields"]

        for key in keys {
            let direct = stringValue(json[key])
            if !direct.isEmpty {
                return direct
            }
        }

        for containerKey in containerKeys {
            if let nested = json[containerKey] as? [String: Any] {
                let nestedValue = firstString(from: nested, keys: keys)
                if !nestedValue.isEmpty {
                    return nestedValue
                }
            } else if let nestedArray = json[containerKey] as? [[String: Any]] {
                for entry in nestedArray {
                    let nestedValue = firstString(from: entry, keys: keys)
                    if !nestedValue.isEmpty {
                        return nestedValue
                    }
                }
            }
        }

        return ""
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
