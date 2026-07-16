import Foundation

enum AppLanguage {
    static let storageKey = "profile_displayLanguage"

    static func code(for storedValue: String) -> String {
        let normalized = storedValue.lowercased()
        if normalized == "ไทย" || normalized == "thai" || normalized.hasPrefix("th-") || normalized.hasPrefix("th_") || normalized == "th" {
            return "th"
        }
        return "en"
    }

    static var currentCode: String {
        code(for: UserDefaults.standard.string(forKey: storageKey) ?? "en")
    }

    static func localized(
        _ key: String,
        locale: Locale? = nil,
        arguments: [CVarArg] = []
    ) -> String {
        let languageCode = locale.map { code(for: $0.identifier) } ?? currentCode
        let bundle = Bundle.main.path(forResource: languageCode, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale ?? Locale(identifier: languageCode), arguments: arguments)
    }
}
