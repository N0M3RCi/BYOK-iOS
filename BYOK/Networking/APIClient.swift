import Foundation

/// Errors thrown by the API client.
enum APIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
    case unauthorized
    case networkError(String)
    case serverError(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code, let message): return message ?? "HTTP error \(code)"
        case .decodingError(let detail): return "Failed to parse response: \(detail)"
        case .unauthorized: return "Session expired. Please log in again."
        case .networkError(let detail): return detail
        case .serverError(let message): return message
        case .unknown(let detail): return detail
        }
    }
}

// MARK: - API Client Configuration
struct APIConfig {
    static let shared = APIConfig()

    var brainBaseURL: String {
        UserDefaults.standard.string(forKey: "brain_endpoint") ?? "https://class.n0m3rci.cc/enter"
    }

    var apiBaseURL: String {
        "\(brainBaseURL)/api/v1"
    }

    var brainServiceURL: String {
        brainBaseURL
    }
}

// MARK: - API Client
final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
    }

    // MARK: - Auth Headers

    func authHeaders() async -> [String: String] {
        var headers: [String: String] = [:]
        if let token = KeychainManager.shared.getToken() {
            headers["Authorization"] = "Bearer \(token)"
        }
        headers["X-Channel"] = "ios"
        if let sessionID = KeychainManager.shared.getSessionID() {
            headers["X-Session-ID"] = sessionID
        }
        if let userID = KeychainManager.shared.getUserID() {
            headers["X-User-ID"] = userID
        }
        return headers
    }

    // MARK: - API Server Requests (with HTTP status validation)

    func apiRequest<T: Decodable>(
        method: String,
        path: String,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        let url = try buildURL(base: APIConfig.shared.apiBaseURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if requiresAuth {
            let headers = await authHeaders()
            headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        // Check server error format: {"code": X, "text": "..."}
        if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = errorResponse["code"] as? Int, code != 0 {
            let text = errorResponse["text"] as? String ?? "Request failed"
            throw APIError.serverError(text)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Raw Request (always parses JSON body like web app's proxyFetchPost)
    // Does NOT throw on non-2xx HTTP — always tries to parse the response body

    func rawRequest(
        method: String = "POST",
        path: String,
        body: [String: String] = [:],
        requiresAuth: Bool = false
    ) async throws -> [String: Any] {
        let url = try buildURL(base: APIConfig.shared.apiBaseURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if requiresAuth {
            let headers = await authHeaders()
            headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        }

        if !body.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, _) = try await session.data(for: request)

        // Always try to parse JSON body (matches web app handleResponse)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("Invalid JSON response")
        }

        // Check server error format: code !== 0 means error (web app convention)
        if let code = json["code"] as? Int, code != 0 {
            let text = json["text"] as? String ?? "Request failed"
            throw APIError.serverError(text)
        }

        return json
    }

    // MARK: - Brain Service Requests

    func brainRequest<T: Decodable>(
        method: String,
        path: String,
        body: Encodable? = nil
    ) async throws -> T {
        let url = try buildURL(base: APIConfig.shared.brainServiceURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let headers = await authHeaders()
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        return try decoder.decode(T.self, from: data)
    }

    func brainDelete<T: Decodable>(path: String) async throws -> T {
        try await brainRequest(method: "DELETE", path: path)
    }

    func brainGet<T: Decodable>(path: String) async throws -> T {
        try await brainRequest(method: "GET", path: path)
    }

    func brainPost<T: Decodable>(path: String, body: Encodable? = nil) async throws -> T {
        try await brainRequest(method: "POST", path: path, body: body)
    }

    func brainPut<T: Decodable>(path: String, body: Encodable? = nil) async throws -> T {
        try await brainRequest(method: "PUT", path: path, body: body)
    }

    func getRemoteSubAgentProviders() async throws -> [RemoteSubAgentProvider] {
        try await brainGet(path: "/remote-subagents/providers")
    }

    // MARK: - Multipart Upload

    func uploadFile(data: Data, filename: String) async throws -> FileUploadResponse {
        let url = try buildURL(base: APIConfig.shared.brainServiceURL, path: "/files")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let headers = await authHeaders()
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(FileUploadResponse.self, from: responseData)
    }

    // MARK: - Helpers

    private func buildURL(base: String, path: String) throws -> URL {
        guard let url = URL(string: "\(base)\(path)") else {
            throw APIError.invalidURL
        }
        return url
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }
    }
}

// MARK: - AnyEncodable helper for type-erased encoding
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        _encode = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}