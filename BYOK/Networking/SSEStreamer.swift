import Foundation

/// Manages Server-Sent Events (SSE) streaming for the chat feature.
final class SSEStreamer: @unchecked Sendable {
    private var sessionTask: URLSessionTask?
    private var continuation: AsyncStream<SSEEvent>.Continuation?

    private let streamingSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        return URLSession(configuration: config)
    }()

    /// Starts an SSE stream and returns an AsyncStream of parsed events.
    func streamChat(
        request: ChatRequest,
        token: String,
        sessionID: String,
        userID: String
    ) -> AsyncStream<SSEEvent> {
        return AsyncStream { continuation in
            self.continuation = continuation

            Task(priority: .userInitiated) { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }
                do {
                    let url = URL(string: "\(APIConfig.shared.brainServiceURL)/chat")!
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    urlRequest.setValue("ios", forHTTPHeaderField: "X-Channel")
                    urlRequest.setValue(sessionID, forHTTPHeaderField: "X-Session-ID")
                    urlRequest.setValue(userID, forHTTPHeaderField: "X-User-ID")
                    urlRequest.httpBody = try JSONEncoder().encode(request)
                    urlRequest.timeoutInterval = 30
                    urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

                    let (bytes, response) = try await streamingSession.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        if let httpResponse = response as? HTTPURLResponse {
                            print("[SSE] HTTP error: \(httpResponse.statusCode)")
                        }
                        continuation.finish()
                        self.continuation = nil
                        return
                    }

                    var currentEvent = ""
                    var lineBuffer = ""
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            let line = lineBuffer
                            lineBuffer = ""
                            if line.hasPrefix("data: ") {
                                currentEvent = String(line.dropFirst(6))
                            } else if line.hasPrefix(":") {
                                continue
                            } else if line.isEmpty && !currentEvent.isEmpty {
                                if let data = currentEvent.data(using: .utf8),
                                   let event = try? JSONDecoder().decode(SSEEvent.self, from: data) {
                                    continuation.yield(event)
                                    if event.step == "end" || event.step == "error" {
                                        continuation.finish()
                                        self.continuation = nil
                                        return
                                    }
                                }
                                currentEvent = ""
                            }
                        } else {
                            lineBuffer.append(Character(UnicodeScalar(byte)))
                        }
                    }
                    continuation.finish()
                    self.continuation = nil
                } catch {
                    print("[SSE] Stream error: \(error.localizedDescription)")
                    continuation.finish()
                    self.continuation = nil
                }
            }
        }
    }

    /// Stops the current SSE stream.
    func stop() {
        sessionTask?.cancel()
        continuation?.finish()
        continuation = nil
    }

    deinit {
        stop()
    }
}