import Foundation
import Combine

/// Captures API request/response details for debugging
final class APIDebugLogger: ObservableObject {
    static let shared = APIDebugLogger()

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let method: String
        let url: String
        let requestBody: String
        let statusCode: Int
        let responseBody: String
        let error: String?
    }

    @Published var entries: [LogEntry] = []
    private let lock = NSLock()

    func log(
        method: String,
        path: String,
        requestBody: [String: String],
        statusCode: Int,
        responseBody: String,
        error: String? = nil
    ) {
        let entry = LogEntry(
            timestamp: Date(),
            method: method,
            url: path,
            requestBody: requestBody.map { "\($0.key)=\($0.value.prefix(20))..." }.joined(separator: ", "),
            statusCode: statusCode,
            responseBody: String(responseBody.prefix(500)),
            error: error
        )
        lock.lock()
        entries.append(entry)
        entries = Array(entries.suffix(50))
        lock.unlock()
        print("[API] \(method) \(path) → \(statusCode): \(responseBody.prefix(200))")
    }

    func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }
}
