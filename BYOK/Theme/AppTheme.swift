import SwiftUI

/// Manages the app's theme (light/dark/system) and persists the preference.
final class ThemeManager: ObservableObject, @unchecked Sendable {
    static let shared = ThemeManager()
    @Published var currentTheme: AppTheme = {
        let raw = UserDefaults.standard.string(forKey: "app_theme") ?? AppTheme.system.rawValue
        return AppTheme(rawValue: raw) ?? .system
    }() {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
        }
    }

    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
}