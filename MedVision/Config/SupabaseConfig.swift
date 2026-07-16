import Foundation
import Supabase

enum SupabaseConfig {
    /// OAuth / magic-link return URL registered in Supabase Auth URL config.
    static let oauthRedirectURL = URL(string: "com.Kao.MedVision://login-callback")!

    static var isConfigured: Bool {
        let urlHost = projectURL.host ?? ""
        let key = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !urlHost.contains("YOUR_PROJECT")
            && !key.isEmpty
            && key != "YOUR_SUPABASE_ANON_KEY"
    }

    static var projectURL: URL { SupabaseSecrets.projectURL }

    static var anonKey: String { SupabaseSecrets.anonKey }

    static func makeClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: projectURL,
            supabaseKey: anonKey,
            options: .init(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
