import Foundation

/// On-device consensus for guest / offline OCR — mirrors backend consensusEngine.js
/// Accuracy-first: Thai → gated openFDA → LLM judge always → agreement resolution.
enum LocalConsensusEngine {
    static let hitThreshold = 0.85

    struct MatchResult {
        var source: String
        var name: String
        var score: Double
    }

    struct JudgeResult {
        var name: String?
        var dosage: String?
        var verdict: String
    }

    static func normalizeName(_ input: String) -> String {
        var text = input.lowercased()
        text = text.replacingOccurrences(of: #"[()\[\],;:|/\\]"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(
            of: #"\b\d+(?:\.\d+)?\s?(?:mg|mcg|g|ml|iu|%)\b"#,
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\b(?:tablets?|capsules?|pills?|syrup|suspension|liquid|cream|drops?|inhaler|patch|powder)\b"#,
            with: " ",
            options: .regularExpression
        )
        text = text.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isLatinScriptName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.range(of: #"^[a-zA-Z0-9\s.\-()/]+$"#, options: .regularExpression) != nil
    }

    static func matchThaiMedicine(_ name: String) -> MatchResult? {
        let query = normalizeName(name)
        guard !query.isEmpty else { return nil }

        var best: MatchResult?
        for entry in ThaiMedicineCatalog.all {
            let candidates = ([entry.name] + entry.aliases + [entry.generic])
                .map(normalizeName)
                .filter { !$0.isEmpty }
            for candidate in candidates {
                let score = jaroWinkler(query, candidate)
                if best == nil || score > (best?.score ?? 0) {
                    best = MatchResult(source: "thai", name: entry.name, score: score)
                }
            }
        }

        guard let best, best.score >= hitThreshold else { return nil }
        return best
    }

    /// Agreement-based resolution. All sources equal — no winner-picking on conflict.
    static func resolve(
        ocrName: String,
        ocrDosage: String,
        thai: MatchResult?,
        openFda: MatchResult?,
        judge: JudgeResult?
    ) -> MedicineResolution {
        var candidates: [ResolutionCandidate] = []
        if let thai {
            candidates.append(ResolutionCandidate(source: "thai", name: thai.name, score: thai.score))
        }
        if let openFda {
            candidates.append(ResolutionCandidate(source: "openfda", name: openFda.name, score: openFda.score))
        }
        if let judgeName = judge?.name, !judgeName.isEmpty, judge?.verdict != "uncertain" {
            candidates.append(
                ResolutionCandidate(
                    source: "judge",
                    name: judgeName,
                    score: nil,
                    dosage: judge?.dosage,
                    verdict: judge?.verdict
                )
            )
        }

        let dosageFromJudge = judge?.dosage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let dosage = (dosageFromJudge?.isEmpty == false ? dosageFromJudge! : ocrDosage)

        if candidates.isEmpty {
            return MedicineResolution(
                status: .unverified,
                finalName: ocrName,
                finalDosage: ocrDosage,
                label: "unverified",
                candidates: candidates,
                judgeSkipped: false
            )
        }

        let distinct = Set(candidates.map { normalizeName($0.name) }.filter { !$0.isEmpty })
        if distinct.count > 1 {
            return MedicineResolution(
                status: .disagreement,
                finalName: nil,
                finalDosage: ocrDosage,
                label: "conflict",
                candidates: candidates,
                judgeSkipped: false
            )
        }

        let sources = Set(candidates.map(\.source))
        let label = (sources.count == 1 && sources.contains("judge")) ? "ai_corrected" : "verified"

        return MedicineResolution(
            status: .consensus,
            finalName: candidates[0].name,
            finalDosage: dosage,
            label: label,
            candidates: candidates,
            judgeSkipped: false
        )
    }

    static func lookupOpenFda(name: String) async -> MatchResult? {
        guard isLatinScriptName(name) else { return nil }
        let query = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        guard !query.isEmpty else { return nil }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let search = "openfda.generic_name:\"\(encoded)\"+OR+openfda.brand_name:\"\(encoded)\""
        let searchEncoded = search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search
        guard let url = URL(string: "https://api.fda.gov/drug/label.json?limit=1&search=\(searchEncoded)") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let openfda = first["openfda"] as? [String: Any] else {
                return nil
            }

            let brands = openfda["brand_name"] as? [String] ?? []
            let generics = openfda["generic_name"] as? [String] ?? []
            let candidate = brands.first ?? generics.first
            guard let candidate, !candidate.isEmpty else { return nil }
            return MatchResult(source: "openfda", name: candidate, score: 1.0)
        } catch {
            return nil
        }
    }

    /// Sequential: Thai → gated openFDA → judge always → resolve by agreement.
    static func run(
        ocrName: String,
        ocrDosage: String,
        callJudge: ((MatchResult?, MatchResult?) async -> JudgeResult?)? = nil
    ) async -> MedicineResolution {
        let thai = matchThaiMedicine(ocrName)
        let openFda = await lookupOpenFda(name: ocrName)

        var judge: JudgeResult?
        if let callJudge {
            judge = await callJudge(thai, openFda)
        }

        return resolve(
            ocrName: ocrName,
            ocrDosage: ocrDosage,
            thai: thai,
            openFda: openFda,
            judge: judge
        )
    }

    // MARK: - Jaro-Winkler

    private static func jaroWinkler(_ s1: String, _ s2: String) -> Double {
        let a = Array(s1)
        let b = Array(s2)
        if a == b { return 1 }
        if a.isEmpty || b.isEmpty { return 0 }

        let matchDistance = max(0, max(a.count, b.count) / 2 - 1)
        var aMatches = Array(repeating: false, count: a.count)
        var bMatches = Array(repeating: false, count: b.count)
        var matches = 0
        var transpositions = 0

        for i in 0..<a.count {
            let start = max(0, i - matchDistance)
            let end = min(i + matchDistance + 1, b.count)
            if start >= end { continue }
            for j in start..<end {
                if bMatches[j] || a[i] != b[j] { continue }
                aMatches[i] = true
                bMatches[j] = true
                matches += 1
                break
            }
        }

        if matches == 0 { return 0 }

        var k = 0
        for i in 0..<a.count {
            if !aMatches[i] { continue }
            while !bMatches[k] { k += 1 }
            if a[i] != b[k] { transpositions += 1 }
            k += 1
        }

        let m = Double(matches)
        let jaro = (m / Double(a.count) + m / Double(b.count) + (m - Double(transpositions) / 2) / m) / 3

        var prefix = 0
        let maxPrefix = min(4, min(a.count, b.count))
        while prefix < maxPrefix && a[prefix] == b[prefix] {
            prefix += 1
        }

        return jaro + Double(prefix) * 0.1 * (1 - jaro)
    }
}
