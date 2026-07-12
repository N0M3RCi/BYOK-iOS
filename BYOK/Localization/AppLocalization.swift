import Foundation

/// Lightweight localization manager.
/// Uses bundled JSON files for each language.
final class LocalizationManager: ObservableObject, @unchecked Sendable {
    static let shared = LocalizationManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
            loadStrings()
        }
    }

    private var strings: [String: String] = [:]

    private init() {
        let raw = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.en.rawValue
        currentLanguage = AppLanguage(rawValue: raw) ?? .en
        loadStrings()
    }

    private func loadStrings() {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            strings = [:]
            return
        }
        strings = dict
    }

    func localized(_ key: String) -> String {
        strings[key] ?? key
    }

    func localized(_ key: String, _ args: CVarArg...) -> String {
        let format = strings[key] ?? key
        return String(format: format, arguments: args)
    }
}

// Convenience wrapper
func loc(_ key: String) -> String {
    LocalizationManager.shared.localized(key)
}

func loc(_ key: String, _ args: CVarArg...) -> String {
    LocalizationManager.shared.localized(key, args)
}