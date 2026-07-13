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

            guard let token = KeychainManager.shared.getToken() else {
                testResult = "Not logged in — no auth token found"
                return false
            }

            let base = APIConfig.shared.apiBaseURL
            guard let url = URL(string: "\(base)/provider/test") else {
                testResult = "Invalid URL"
                return false
            }

            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            let bodyStr = String(data: data, encoding: .utf8) ?? "Non-UTF8 data"

            APIDebugLogger.shared.log(
                method: "PUT",
                path: "/api/v1/provider/test",
                requestBody: body,
                statusCode: statusCode,
                responseBody: bodyStr
            )

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                testResult = "Non-JSON response (HTTP \(statusCode)): \(bodyStr.prefix(120))"
                return false
            }

            // Try all possible success/error response formats
            if let code = json["code"] as? Int {
                if code == 0 {
                    testResult = json["text"] as? String ?? json["message"] as? String ?? "Connection successful"
                    return true
                }
                let msg = json["text"] as? String
                    ?? json["message"] as? String
                    ?? json["error"] as? String
                    ?? (json["data"] as? [String: Any])?["error"] as? String
                    ?? (json["data"] as? [String: Any])?["message"] as? String
                    ?? "Server error (code: \(code))"
                testResult = msg
                return false
            }

            // No code field — check is_valid or other formats
            if let dataDict = json["data"] as? [String: Any] {
                if let valid = dataDict["is_valid"] as? Bool {
                    testResult = dataDict["message"] as? String ?? dataDict["error"] as? String ?? (valid ? "Connected" : "Connection failed")
                    return valid
                }
            }

            if let valid = json["is_valid"] as? Bool {
                testResult = json["message"] as? String ?? json["error"] as? String ?? (valid ? "Connected" : "Connection failed")
                return valid
            }

            if (200...299).contains(statusCode) {
                testResult = json["text"] as? String ?? json["message"] as? String ?? "Connected"
                return true
            }

            testResult = "Unexpected (HTTP \(statusCode)): \(bodyStr.prefix(120))"
            return false
        } catch {
            let detail = (error as? URLError)?.localizedDescription ?? error.localizedDescription
            testResult = detail
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

            guard let token = KeychainManager.shared.getToken() else {
                errorMessage = "Not logged in — no auth token found"
                return
            }

            let base = APIConfig.shared.apiBaseURL
            guard let url = URL(string: "\(base)/provider/models") else {
                errorMessage = "Invalid URL"
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            let bodyStr = String(data: data, encoding: .utf8) ?? "Non-UTF8 data"

            APIDebugLogger.shared.log(
                method: "PUT",
                path: "/api/v1/provider/models",
                requestBody: body,
                statusCode: statusCode,
                responseBody: bodyStr
            )

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                errorMessage = "Non-JSON response (HTTP \(statusCode)): \(bodyStr.prefix(120))"
                return
            }

            // Check for server error
            if let code = json["code"] as? Int, code != 0 {
                let msg = json["text"] as? String
                    ?? json["message"] as? String
                    ?? json["error"] as? String
                    ?? "Server error (code: \(code))"
                errorMessage = msg
                return
            }

            guard (200...299).contains(statusCode) else {
                errorMessage = "Server error (HTTP \(statusCode))"
                return
            }

            // Parse models from response (handles multiple formats)
            if let models = json["models"] as? [[String: String]] {
                availableModels = models.map { ProviderModel(id: $0["id"] ?? $0["name"] ?? "", name: $0["name"] ?? $0["id"] ?? "") }
            } else if let modelsData = json["data"] as? [[String: String]] {
                availableModels = modelsData.map { ProviderModel(id: $0["id"] ?? $0["name"] ?? "", name: $0["name"] ?? $0["id"] ?? "") }
            } else if let modelNames = json["modelNames"] as? [String] {
                availableModels = modelNames.map { ProviderModel(id: $0, name: $0) }
            } else if let dataDict = json["data"] as? [String: Any], let models = dataDict["models"] as? [[String: String]] {
                availableModels = models.map { ProviderModel(id: $0["id"] ?? $0["name"] ?? "", name: $0["name"] ?? $0["id"] ?? "") }
            } else {
                errorMessage = "No models found in response"
            }
        } catch {
            let detail = (error as? URLError)?.localizedDescription ?? error.localizedDescription
            errorMessage = detail
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