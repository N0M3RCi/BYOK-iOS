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
    @Published var availableModels: [ProviderModel] = []
    @Published var selectedModel: String?
    @Published var testResult: String?
    @Published var isTesting = false
    @Published var isFetchingModels = false

    private let apiClient = APIClient.shared

    init() {
        brainEndpoint = UserDefaults.standard.string(forKey: "brain_endpoint") ?? "https://class.n0m3rci.cc/enter"
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
                let brain = APIConfig.shared.brainServiceURL
                let api = APIConfig.shared.apiBaseURL
                // Check both endpoints — brain service root + API
                var brainOK = false
                var apiOK = false
                if let brainURL = URL(string: brain) {
                    var req = URLRequest(url: brainURL)
                    req.httpMethod = "GET"
                    req.timeoutInterval = 10
                    if let (_, r) = try? await URLSession.shared.data(for: req),
                       r is HTTPURLResponse { brainOK = true }
                }
                if let apiURL = URL(string: "\(api)/auth/passcode-login") {
                    var req = URLRequest(url: apiURL)
                    req.httpMethod = "GET"
                    req.timeoutInterval = 10
                    if let (_, r) = try? await URLSession.shared.data(for: req),
                       r is HTTPURLResponse { apiOK = true }
                }
                isConnected = brainOK || apiOK
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

    func addProvider(platform: String, apiKey: String, apiUrl: String?, modelType: String? = nil) async {
        do {
            var body: [String: String] = [
                "platform": platform,
                "api_key": apiKey
            ]
            if let url = apiUrl { body["api_url"] = url }
            let provider: Provider = try await apiClient.apiRequest(
                method: "POST",
                path: "/provider",
                body: body
            )
if let modelType = modelType {
                let modelBody: [String: String] = [
                    "provider_id": provider.id,
                    "model_type": modelType
                ]
                let _: EmptyResponse = try await apiClient.apiRequest(
                    method: "PUT",
                    path: "/provider/active-model",
                    body: modelBody
                )
            }
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

    // MARK: - Provider Management

    func testProviderConnection(platform: String, apiKey: String, apiUrl: String?) async -> Bool {
        isTesting = true
        testResult = nil
        defer { isTesting = false }

        do {
            var body: [String: String] = [
                "platform": platform,
                "api_key": apiKey
            ]
            if let url = apiUrl, !url.isEmpty { body["api_url"] = url }

            let result = try await apiClient.brainRawPost(
                path: "/provider/test",
                body: body
            )
            testResult = (result["message"] as? String) ?? (result["text"] as? String) ?? "Connection successful"
            return true
        } catch {
            testResult = "Connection failed: \(error.localizedDescription)"
            return false
        }
    }

    func fetchProviderModels(platform: String, apiKey: String, apiUrl: String?) async {
        isFetchingModels = true
        availableModels = []
        selectedModel = nil
        defer { isFetchingModels = false }

        do {
            var body: [String: String] = [
                "platform": platform,
                "api_key": apiKey
            ]
            if let url = apiUrl, !url.isEmpty { body["api_url"] = url }

            let result = try await apiClient.brainRawPost(
                path: "/model/list",
                body: body
            )
            // Parse models from response (handles multiple response formats)
            if let models = result["models"] as? [[String: String]] {
                availableModels = models.map { ProviderModel(id: $0["id"] ?? $0["name"] ?? "", name: $0["name"] ?? $0["id"] ?? "") }
            } else if let data = result["data"] as? [[String: String]] {
                availableModels = data.map { ProviderModel(id: $0["id"] ?? $0["name"] ?? "", name: $0["name"] ?? $0["id"] ?? "") }
            } else if let modelNames = result["modelNames"] as? [String] {
                availableModels = modelNames.map { ProviderModel(id: $0, name: $0) }
            } else if let data = result["data"] as? [String: Any], let models = data["models"] as? [[String: String]] {
                availableModels = models.map { ProviderModel(id: $0["id"] ?? $0["name"] ?? "", name: $0["name"] ?? $0["id"] ?? "") }
            }
        } catch {
            errorMessage = "Failed to fetch models: \(error.localizedDescription)"
        }
    }

    func setActiveModel(providerId: String, modelType: String) {
        selectedModel = modelType
        Task {
            do {
                let body: [String: String] = [
                    "provider_id": providerId,
                    "model_type": modelType
                ]
                let _: EmptyResponse = try await apiClient.apiRequest(
                    method: "PUT",
                    path: "/provider/active-model",
                    body: body
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteProvider(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let provider = providers[index]
                do {
                    let _: EmptyResponse = try await apiClient.apiRequest(
                        method: "DELETE",
                        path: "/provider/\(provider.id)"
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            loadProviders()
        }
    }
}

extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}