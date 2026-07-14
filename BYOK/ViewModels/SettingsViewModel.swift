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
            let brain = APIConfig.shared.brainServiceURL
            let api = APIConfig.shared.apiBaseURL
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
            isLoading = false
        }
    }

    func loadProviders() {
        Task {
            do {
                let response: PaginatedResponse<Provider> = try await apiClient.apiRequest(
                    method: "GET",
                    path: "/providers"
                )
                providers = response.items
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func addProvider(platform: String, apiKey: String, apiUrl: String?, modelType: String? = nil) async {
        do {
            var body: [String: String] = [
                "provider_name": platform,
                "endpoint_url": apiUrl ?? "https://api.openai.com/v1",
                "api_key": apiKey,
                "platform": platform,
                "api_url": apiUrl ?? ""
            ]
            if let url = apiUrl, !url.isEmpty { body["endpoint_url"] = url; body["api_url"] = url }
            if let model = modelType, !model.isEmpty { body["model_type"] = model }
            let provider: Provider = try await apiClient.apiRequest(
                method: "POST",
                path: "/provider",
                body: body
            )
if let modelType = modelType {
                let modelBody: [String: String] = [
                    "provider_id": "\(provider.id)",
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

        // Determine the base URL for the API
        let baseURL: String
        if let url = apiUrl, !url.isEmpty {
            baseURL = url.hasSuffix("/") ? String(url.dropLast()) : url
        } else {
            baseURL = "https://api.openai.com/v1"
        }

        // Try direct API call to the provider's models endpoint
        let modelsURL = baseURL.hasSuffix("/v1") ? "\(baseURL)/models" : "\(baseURL)/v1/models"
        guard let url = URL(string: modelsURL) else {
            testResult = "Invalid API URL: \(modelsURL)"
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            let bodyStr = String(data: data, encoding: .utf8) ?? "Non-UTF8 data"

            APIDebugLogger.shared.log(
                method: "GET",
                path: modelsURL,
                requestBody: ["api_key": apiKey.prefix(8) + "..."],
                statusCode: statusCode,
                responseBody: bodyStr
            )

            if (200...299).contains(statusCode) {
                testResult = "Connected successfully"
                return true
            }

            // Try parsing error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let msg = json["error"] as? String
                    ?? (json["error"] as? [String: Any])?["message"] as? String
                    ?? json["message"] as? String
                    ?? "HTTP \(statusCode)"
                testResult = msg
            } else {
                testResult = "HTTP \(statusCode): \(bodyStr.prefix(100))"
            }
            return false
        } catch {
            let detail = (error as? URLError)?.localizedDescription ?? error.localizedDescription
            testResult = "Connection failed: \(detail)"
            APIDebugLogger.shared.log(
                method: "GET",
                path: modelsURL,
                requestBody: ["api_key": apiKey.prefix(8) + "..."],
                statusCode: 0,
                responseBody: "",
                error: detail
            )
            return false
        }
    }

    func fetchProviderModels(platform: String, apiKey: String, apiUrl: String?) async {
        isFetchingModels = true
        availableModels = []
        selectedModel = nil
        defer { isFetchingModels = false }

        // Determine the base URL
        let baseURL: String
        if let url = apiUrl, !url.isEmpty {
            baseURL = url.hasSuffix("/") ? String(url.dropLast()) : url
        } else {
            baseURL = "https://api.openai.com/v1"
        }

        // Call the provider's models endpoint directly
        let modelsURL = baseURL.hasSuffix("/v1") ? "\(baseURL)/models" : "\(baseURL)/v1/models"
        guard let url = URL(string: modelsURL) else {
            errorMessage = "Invalid API URL: \(modelsURL)"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            let bodyStr = String(data: data, encoding: .utf8) ?? "Non-UTF8 data"

            APIDebugLogger.shared.log(
                method: "GET",
                path: modelsURL,
                requestBody: ["api_key": apiKey.prefix(8) + "..."],
                statusCode: statusCode,
                responseBody: bodyStr
            )

            guard (200...299).contains(statusCode) else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let msg = json["error"] as? String
                        ?? (json["error"] as? [String: Any])?["message"] as? String
                        ?? json["message"] as? String
                        ?? "HTTP \(statusCode)"
                    errorMessage = msg
                } else {
                    errorMessage = "HTTP \(statusCode): \(bodyStr.prefix(100))"
                }
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                errorMessage = "Non-JSON response from provider"
                return
            }

            // Parse OpenAI-compatible model list format: { "data": [{ "id": "...", ... }, ...] }
            if let models = json["data"] as? [[String: Any]] {
                availableModels = models.compactMap { model in
                    guard let id = model["id"] as? String else { return nil }
                    let name = model["name"] as? String ?? model["id"] as? String ?? id
                    return ProviderModel(id: id, name: name)
                }
            }

            if availableModels.isEmpty {
                errorMessage = "No models found in response"
            }
        } catch {
            let detail = (error as? URLError)?.localizedDescription ?? error.localizedDescription
            errorMessage = "Failed to fetch models: \(detail)"
            APIDebugLogger.shared.log(
                method: "GET",
                path: modelsURL,
                requestBody: ["api_key": apiKey.prefix(8) + "..."],
                statusCode: 0,
                responseBody: "",
                error: detail
            )
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