import Foundation

/// Manages Server-Sent Events (SSE) streaming for the chat feature.
final class SSEStreamer: @unchecked Sendable {
    private var sessionTask: URLSessionTask?
    private var continuation: AsyncStream<SSEEvent>.Continuation?

    /// Starts an SSE stream and returns an AsyncStream of parsed events.
    func streamChat(
        request: ChatRequest,
        token: String,
        sessionID: String,
        userID: String
    ) -> AsyncStream<SSEEvent> {
        return AsyncStream { [weak self] continuation in
            guard let self = self else { return }
            self.continuation = continuation

            Task {
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
                    urlRequest.timeoutInterval = 3600 // 60 minutes

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        continuation.finish()
                        return
                    }

                    var currentEvent = ""
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            currentEvent = String(line.dropFirst(6))
                        } else if line.hasPrefix(":") {
                            // Heartbeat - skip
                            continue
                        } else if line.isEmpty && !currentEvent.isEmpty {
                            // End of event - parse
                            if let data = currentEvent.data(using: .utf8),
                               let event = try? JSONDecoder().decode(SSEEvent.self, from: data) {
                                continuation.yield(event)
                                if event.step == "end" || event.step == "error" {
                                    continuation.finish()
                                    return
                                }
                            }
                            currentEvent = ""
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
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