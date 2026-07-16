import Foundation

/// Syncs local SwiftData dose events to Supabase for LINE missed-dose alerts.
@MainActor
enum DoseSyncService {
    private static let graceMinutes: TimeInterval = 30 * 60
    private static let pendingQueueKey = "dose_sync_pending_queue"

    struct SyncPayload: Codable, Equatable {
        var clientKey: String
        var medicineName: String
        var dosage: String
        var form: String
        var scheduledFor: String
        var status: String
        var takenAt: String?
    }

    static func clientKey(for event: DoseEvent) -> String? {
        guard let tag = event.medicine?.notificationTag else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        // Stable key: medicine tag + scheduled minute (drop seconds).
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: event.scheduledTime)
        guard let floored = cal.date(from: comps) else { return nil }
        return "\(tag)|\(formatter.string(from: floored))"
    }

    static func mirrorMissedStatuses(events: [DoseEvent]) {
        let cutoff = Date().addingTimeInterval(-graceMinutes)
        for event in events where event.status == .pending && event.scheduledTime < cutoff {
            event.status = .missed
        }
    }

    static func enqueue(_ payload: SyncPayload) {
        var queue = loadQueue()
        queue.removeAll { $0.clientKey == payload.clientKey }
        queue.append(payload)
        saveQueue(queue)
    }

    static func syncEvent(_ event: DoseEvent, accessToken: String?) async {
        guard let token = accessToken, !token.isEmpty else { return }
        guard let payload = makePayload(from: event) else { return }
        enqueue(payload)
        await flush(accessToken: token)
    }

    static func syncEvents(_ events: [DoseEvent], accessToken: String?) async {
        guard let token = accessToken, !token.isEmpty else { return }
        for event in events {
            if let payload = makePayload(from: event) {
                enqueue(payload)
            }
        }
        await flush(accessToken: token)
    }

    static func flush(accessToken: String) async {
        guard SupabaseConfig.isConfigured else { return }
        let queue = loadQueue()
        guard !queue.isEmpty else { return }

        var remaining: [SyncPayload] = []
        for payload in queue {
            do {
                try await postUpsert(payload, accessToken: accessToken)
            } catch {
                remaining.append(payload)
            }
        }
        saveQueue(remaining)
    }

    private static func makePayload(from event: DoseEvent) -> SyncPayload? {
        guard let medicine = event.medicine,
              let key = clientKey(for: event) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let takenAt: String? = {
            guard let taken = event.takenTime else { return nil }
            return formatter.string(from: taken)
        }()
        return SyncPayload(
            clientKey: key,
            medicineName: medicine.name,
            dosage: medicine.dosage,
            form: medicine.form.rawValue.lowercased(),
            scheduledFor: formatter.string(from: event.scheduledTime),
            status: event.status.rawValue,
            takenAt: takenAt
        )
    }

    private static func postUpsert(_ payload: SyncPayload, accessToken: String) async throws {
        let endpoint = SupabaseConfig.projectURL.appendingPathComponent("functions/v1/dose-events")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 30

        var body: [String: Any] = [
            "clientKey": payload.clientKey,
            "medicineName": payload.medicineName,
            "dosage": payload.dosage,
            "form": payload.form,
            "scheduledFor": payload.scheduledFor,
            "status": payload.status
        ]
        if let takenAt = payload.takenAt {
            body["takenAt"] = takenAt
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "dose sync failed"
            throw NSError(domain: "DoseSync", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private static func loadQueue() -> [SyncPayload] {
        guard let data = UserDefaults.standard.data(forKey: pendingQueueKey),
              let decoded = try? JSONDecoder().decode([SyncPayload].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func saveQueue(_ queue: [SyncPayload]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: pendingQueueKey)
        }
    }
}
