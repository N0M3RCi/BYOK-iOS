import SwiftUI

@main
@MainActor
struct BYOKApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .biometricLock()
                .onAppear {
                    authViewModel.checkAutoLogin()
                }
        }
    }
}