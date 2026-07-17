import Foundation

/// Rules-first PII scrub for pharmacy-label OCR (mirrors backend/src/scrubPii.js).
enum PiiScrubber {
    static let redacted = "[REDACTED]"

    struct Result {
        var scrubbedText: String
        var redactionCount: Int
        var categories: [String]
    }

    private static let protectedTokens: Set<String> = {
        var tokens: Set<String> = [
            "paracetamol", "acetaminophen", "ibuprofen", "amoxicillin",
            "mg", "mcg", "ml", "tablet", "tablets", "capsule", "capsules", "syrup",
            "หลังอาหาร", "ก่อนอาหาร", "พร้อมอาหาร", "เม็ด", "แคปซูล", "ยาน้ำ"
        ]
        for entry in ThaiMedicineCatalog.all {
            for value in ([entry.name, entry.generic] + entry.aliases) {
                let lower = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard !lower.isEmpty else { continue }
                tokens.insert(lower)
                for part in lower.split(separator: " ") where part.count >= 3 {
                    tokens.insert(String(part))
                }
            }
        }
        return tokens
    }()

    private static func extractNaturalText(_ rawText: String) -> String {
        let trimmed = rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(
                of: #"^```(?:json)?\s*|\s*```$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        guard
            let data = trimmed.data(using: .utf8),
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let naturalText = payload["natural_text"] as? String
        else {
            return rawText
        }
        return naturalText
    }

    static func scrub(_ rawText: String) -> Result {
        guard !rawText.isEmpty else {
            return Result(scrubbedText: "", redactionCount: 0, categories: [])
        }

        var categories = Set<String>()
        var redactionCount = 0
        var text = Self.extractNaturalText(rawText)

        func isProtected(_ span: String) -> Bool {
            let lower = span.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if lower.isEmpty { return false }
            if Self.protectedTokens.contains(lower) { return true }
            if lower.range(of: #"\d+\s?(?:mg|mcg|g|ml|iu|%)"#, options: .regularExpression) != nil {
                return true
            }
            if lower.range(
                of: #"(?:หลังอาหาร|ก่อนอาหาร|พร้อมอาหาร|morning|evening|with food)"#,
                options: .regularExpression
            ) != nil {
                return true
            }
            return false
        }

        func apply(
            pattern: String,
            options: NSRegularExpression.Options = [],
            category: String,
            replace: ((String) -> String)? = nil
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
                return
            }
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: nsRange).reversed()
            for match in matches {
                guard let range = Range(match.range, in: text) else { continue }
                let matched = String(text[range])
                if isProtected(matched) { continue }
                let replacement = replace?(matched) ?? Self.redacted
                if replacement != matched {
                    redactionCount += 1
                    categories.insert(category)
                    text.replaceSubrange(range, with: replacement)
                }
            }
        }

        apply(
            pattern: #"^(?:\s*)(?:patient(?:\s*name)?|name|ชื่อ(?:ผู้ป่วย)?|ชื่อ-สกุล)\s*[:：\-]\s*.+$"#,
            options: [.anchorsMatchLines, .caseInsensitive],
            category: "patient_label"
        )

        apply(
            pattern: #"\b(?:HN|VN|AN|Rx|RX|Prescription(?:\s*No\.?)?)\s*[:#-]?\s*[A-Za-z0-9\-]+"#,
            options: [.caseInsensitive],
            category: "hospital_id"
        )
        apply(
            pattern: #"(?:เลขที่(?:ผู้ป่วย)?|หมายเลข(?:ผู้ป่วย)?|ใบสั่ง(?:ยา)?)\s*[:：]?\s*[A-Za-z0-9\-]+"#,
            options: [],
            category: "hospital_id"
        )

        apply(
            pattern: #"\b(?:age|aged)\s*[:\-]?\s*\d{1,3}(?:\s*(?:years?|yrs?|y\.?o\.?))?\b"#,
            options: [.caseInsensitive],
            category: "age"
        )
        apply(
            pattern: #"อายุ\s*[:：]?\s*\d{1,3}\s*(?:ปี)?"#,
            options: [],
            category: "age"
        )
        apply(
            pattern: #"\b\d{1,3}\s*(?:years?\s*old|yrs?\s*old|y\.?o\.?)\b"#,
            options: [.caseInsensitive],
            category: "age"
        )

        apply(
            pattern: #"\b(?:Mr|Mrs|Ms|Miss|Dr)\.?[ \t]+[A-Z][A-Za-z'’\-]+(?:[ \t]+[A-Z][A-Za-z'’\-]+){0,3}\b"#,
            options: [],
            category: "honorific_en"
        )

        apply(
            pattern: "(?:นางสาว|นาย|นาง|คุณ)[ \\t]*[\\u{0E00}-\\u{0E7F}]+(?:[ \\t]+[\\u{0E00}-\\u{0E7F}]+){0,3}",
            options: [],
            category: "honorific_th"
        )

        apply(
            pattern: #"^(?:\s*)([A-Z][a-zA-Z'’\-]{1,30})\s+([A-Z][a-zA-Z'’\-]{1,30})(?:\s+([A-Z][a-zA-Z'’\-]{1,30}))?(?:\s*)$"#,
            options: [.anchorsMatchLines],
            category: "person_name"
        ) { match in
            if isProtected(match) { return match }
            if match.rangeOfCharacter(from: .decimalDigits) != nil { return match }
            return Self.redacted
        }

        if let collapse = try? NSRegularExpression(
            pattern: #"(?:\[REDACTED\]\s*){2,}"#,
            options: []
        ) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = collapse.stringByReplacingMatches(
                in: text,
                options: [],
                range: range,
                withTemplate: "\(Self.redacted) "
            )
        }

        return Result(
            scrubbedText: text.trimmingCharacters(in: .newlines),
            redactionCount: redactionCount,
            categories: Array(categories).sorted()
        )
    }
}
