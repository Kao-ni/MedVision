import Foundation

/// Talks to caregiver-invite edge function (mint code, status, unlink).
enum CaregiverAlertService {
    struct LinkStatus {
        var linked: Bool
        var lineUserId: String?
    }

    struct Invite {
        var code: String
        var expiresAt: String
        var instructions: String
    }

    static func fetchStatus(accessToken: String) async throws -> LinkStatus {
        let json = try await request(method: "GET", accessToken: accessToken)
        let linked = json["linked"] as? Bool ?? false
        let link = json["link"] as? [String: Any]
        return LinkStatus(linked: linked, lineUserId: link?["line_user_id"] as? String)
    }

    static func createInvite(accessToken: String) async throws -> Invite {
        let json = try await request(method: "POST", accessToken: accessToken)
        guard let code = json["code"] as? String else {
            throw NSError(domain: "CaregiverAlert", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Invite response missing code"
            ])
        }
        return Invite(
            code: code,
            expiresAt: json["expiresAt"] as? String ?? "",
            instructions: json["instructions"] as? String ?? ""
        )
    }

    static func unlink(accessToken: String) async throws {
        _ = try await request(method: "DELETE", accessToken: accessToken)
    }

    private static func request(method: String, accessToken: String) async throws -> [String: Any] {
        guard SupabaseConfig.isConfigured else {
            throw NSError(domain: "CaregiverAlert", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Supabase is not configured"
            ])
        }
        let endpoint = SupabaseConfig.projectURL.appendingPathComponent("functions/v1/caregiver-invite")
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw NSError(domain: "CaregiverAlert", code: httpStatus(response), userInfo: [
                NSLocalizedDescriptionKey: message
            ])
        }
        if data.isEmpty { return [:] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private static func httpStatus(_ response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? 0
    }
}
