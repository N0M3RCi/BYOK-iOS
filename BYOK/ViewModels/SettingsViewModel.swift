import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var brainEndpoint: String {
        didSet { UserDefaults.standard.set(brainEndpoint, forKey: "brain_endpoint") }
    }
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "font_size") }
    }
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var providers: [Provider] = []
    @Published var config: AppConfig?

    private let apiClient = APIClient.shared

    init() {
        brainEndpoint = UserDefaults.standard.string(forKey: "brain_endpoint") ?? "https://class.n0m3rci.cc"
        fontSize = UserDefaults.standard.double(forKey: "font_size").nonZero ?? 16.0
    }

    func loadConfig() {
        Task {
            do {
                let response: AppConfig = try await apiClient.apiRequest(
                    method: "GET",
                    path: "/config"
                )
                config = response
                if let lang = response.language {
                    LocalizationManager.shared.currentLanguage = AppLanguage(rawValue: lang) ?? .en
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func saveConfig() {
        Task {
            do {
                let body: [String: String] = [
                    "language": LocalizationManager.shared.currentLanguage.rawValue,
                    "theme": ThemeManager.shared.currentTheme.rawValue,
                    "brain_endpoint": brainEndpoint
                ]
                let _: AppConfig = try await apiClient.apiRequest(
                    method: "PUT",
                    path: "/config",
                    body: body
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func checkConnection() {
        isLoading = true
        Task {
            do {
                let _: [String: String] = try await apiClient.apiRequest(
                    method: "GET",
                    path: "/health",
                    requiresAuth: false
                )
                isConnected = true
            } catch {
                isConnected = false
            }
            isLoading = false
        }
    }

    func loadProviders() {
        Task {
            do {
                let response: [Provider] = try await apiClient.apiRequest(
                    method: "GET",
                    path: "/provider"
                )
                providers = response
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func addProvider(platform: String, apiKey: String, apiUrl: String?) async {
        do {
            var body: [String: String] = [
                "platform": platform,
                "api_key": apiKey
            ]
            if let url = apiUrl { body["api_url"] = url }
            let _: Provider = try await apiClient.apiRequest(
                method: "POST",
                path: "/provider",
                body: body
            )
            loadProviders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func validateModel(platform: String, modelType: String, apiKey: String) async -> ModelValidationResult? {
        do {
            let body: [String: String] = [
                "model_platform": platform,
                "model_type": modelType,
                "api_key": apiKey
            ]
            let result: ModelValidationResult = try await apiClient.brainPost(path: "/model/validate", body: body)
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}