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
                // Merge locally stored API keys and URLs into providers (server may not return them)
                providers = response.items.map { provider in
                    var p = provider
                    let keychain = KeychainManager.shared
                    if p.apiKey == nil || p.apiKey?.isEmpty == true {
                        if let localKey = keychain.getProviderAPIKey(forProviderId: p.id) {
                            p = Provider(
                                id: p.id,
                                providerName: p.providerName,
                                modelType: p.modelType,
                                apiKey: localKey,
                                endpointUrl: p.endpointUrl,
                                isValid: p.isValid,
                                prefer: p.prefer
                            )
                        }
                    }
                    if p.endpointUrl == nil || p.endpointUrl?.isEmpty == true {
                        if let localURL = keychain.getProviderURL(forProviderId: p.id) {
                            p = Provider(
                                id: p.id,
                                providerName: p.providerName,
                                modelType: p.modelType,
                                apiKey: p.apiKey,
                                endpointUrl: localURL,
                                isValid: p.isValid,
                                prefer: p.prefer
                            )
                        }
                    }
                    return p
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func addProvider(platform: String, apiKey: String, apiUrl: String?, modelType: String? = nil) async {
        do {
            var body: [String: String] = [
                "provider_name": platform,
                "endpoint_url": apiUrl ?? "",
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
            // Save API key and URL locally since server may not return them
            let keychain = KeychainManager.shared
            keychain.saveProviderAPIKey(apiKey, forProviderId: provider.id)
            if let url = apiUrl, !url.isEmpty {
                keychain.saveProviderURL(url, forProviderId: provider.id)
            }

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

    // MARK: - Provider Management

    func testProviderConnection(platform: String, apiKey: String, apiUrl: String?) async -> Bool {
        isTesting = true
        testResult = nil
        defer { isTesting = false }

        // Use the user-provided URL as-is, no path manipulation
        guard let urlStr = apiUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !urlStr.isEmpty else {
            testResult = "Please enter an API URL"
            return false
        }
        guard let url = URL(string: urlStr) else {
            testResult = "Invalid API URL: \(urlStr)"
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
                path: urlStr,
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
                path: urlStr,
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

        // Use the user-provided URL as-is, no path manipulation
        guard let urlStr = apiUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !urlStr.isEmpty else {
            errorMessage = "Please enter an API URL"
            return
        }
        guard let url = URL(string: urlStr) else {
            errorMessage = "Invalid API URL: \(urlStr)"
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
                path: urlStr,
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
                path: urlStr,
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
                    // Also delete locally stored API key and URL
                    KeychainManager.shared.deleteProviderKeys(forProviderId: provider.id)
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