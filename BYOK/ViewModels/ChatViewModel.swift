import Foundation
import SwiftUI

/// Manages chat state, SSE streaming, messages, and file attachments.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentInput = ""
    @Published var isLoading = false
    @Published var isStreaming = false
    @Published var errorMessage: String?
    @Published var currentProjectID: String?
    @Published var currentTaskID: String?
    @Published var showReasoning = false
    @Published var attachedFiles: [String] = []
    @Published var attachedKnowledgeBaseIds: [String] = []
    @Published var editingMessageId: String?
    @Published var tokenUsage: (input: Int, output: Int)?
    @Published var showModelPicker = false

    // Provider-based model selection
    @Published var providers: [Provider] = []
    @Published var selectedProvider: Provider?
    @Published var providerModels: [ProviderModel] = []
    @Published var selectedProviderModel: ProviderModel?
    @Published var isLoadingProviders = false

    private let apiClient = APIClient.shared
    private let keychain = KeychainManager.shared
    private var streamer: SSEStreamer?

    // MARK: - Provider & Model Loading

    func loadProviders() {
        isLoadingProviders = true
        Task {
            do {
                let response: PaginatedResponse<Provider> = try await apiClient.apiRequest(
                    method: "GET",
                    path: "/providers"
                )
                providers = response.items
                // Auto-select first provider if none selected
                if selectedProvider == nil, let first = providers.first {
                    selectProvider(first)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingProviders = false
        }
    }

    func selectProvider(_ provider: Provider) {
        selectedProvider = provider
        providerModels = []
        selectedProviderModel = nil
        // Fetch models from the provider's API using {base_url}/models
        guard let apiKey = provider.apiKey, !apiKey.isEmpty,
              let endpointUrl = provider.endpointUrl,
              !endpointUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Construct models endpoint URL
        let trimmed = endpointUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelsURL = trimmed.hasSuffix("/models") ? trimmed : (trimmed.hasSuffix("/") ? "\(trimmed)models" : "\(trimmed)/models")
        guard let url = URL(string: modelsURL) else { return }

        Task {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["data"] as? [[String: Any]] {
                providerModels = models.compactMap { model in
                    guard let id = model["id"] as? String else { return nil }
                    let name = model["name"] as? String ?? id
                    return ProviderModel(id: id, name: name)
                }
                // Auto-select first model
                if selectedProviderModel == nil, let first = providerModels.first {
                    selectedProviderModel = first
                }
            }
        }
    }

    var modelDisplayName: String {
        if let model = selectedProviderModel {
            if let provider = selectedProvider {
                return "\(provider.name) - \(model.name)"
            }
            return model.name
        }
        return "No model selected"
    }

    // MARK: - Start New Chat

    func startNewChat(question: String) {
        guard !question.isEmpty else { return }
        let projectID = UUID().uuidString.lowercased()
        let taskID = UUID().uuidString.lowercased()
        currentProjectID = projectID
        currentTaskID = taskID

        let userMessage = ChatMessage(
            id: UUID().uuidString,
            role: .user,
            content: question,
            timestamp: Date(),
            isStreaming: false
        )
        messages.append(userMessage)
        currentInput = ""
        isLoading = true

        Task {
            await sendChatRequest(projectID: projectID, taskID: taskID, question: question)
        }
    }

    // MARK: - Follow-up Message

    func sendFollowUp(question: String) {
        guard let projectID = currentProjectID else {
            startNewChat(question: question)
            return
        }
        let taskID = UUID().uuidString.lowercased()
        currentTaskID = taskID

        let userMessage = ChatMessage(
            id: UUID().uuidString,
            role: .user,
            content: question,
            timestamp: Date(),
            isStreaming: false
        )
        messages.append(userMessage)
        currentInput = ""
        isLoading = true

        Task {
            await sendChatRequest(projectID: projectID, taskID: taskID, question: question)
        }
    }

    // MARK: - Send Chat Request (SSE)

    private func sendChatRequest(projectID: String, taskID: String, question: String) async {
        guard let token = keychain.getToken(),
              let sessionID = keychain.getSessionID() ?? UUID().uuidString.lowercased() as String?,
              let email = keychain.getEmail(),
              let userID = keychain.getUserID() else {
            errorMessage = "Authentication required"
            isLoading = false
            return
        }

        // Ensure session ID exists
        if keychain.getSessionID() == nil {
            keychain.saveSessionID(sessionID)
        }

        // Use the selected provider's API key and URL, or empty defaults
        let apiKey = selectedProvider?.apiKey ?? ""
        let apiUrl = selectedProvider?.endpointUrl
        let modelType = selectedProviderModel?.id ?? "gpt-4o"
        let modelPlatform = selectedProvider?.providerName ?? "OPENAI"

        let request = ChatRequest(
            taskId: taskID,
            projectId: projectID,
            question: question,
            email: email,
            modelPlatform: modelPlatform,
            modelType: modelType,
            apiKey: apiKey,
            apiUrl: apiUrl,
            language: LocalizationManager.shared.currentLanguage.rawValue,
            sessionMode: "workforce",
            userId: userID,
            serverUrl: "\(APIConfig.shared.brainBaseURL)/v1",
            attaches: [],
            knowledgeBaseIds: attachedKnowledgeBaseIds.isEmpty ? nil : attachedKnowledgeBaseIds
        )

        let streamer = SSEStreamer()
        self.streamer = streamer
        isStreaming = true
        isLoading = false

        let assistantMessage = ChatMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: "",
            timestamp: Date(),
            reasoning: nil,
            toolCalls: nil,
            isStreaming: true
        )
        messages.append(assistantMessage)

        var reasoningText = ""
        var toolCalls: [ToolCallInfo] = []

        for await event in streamer.streamChat(
            request: request,
            token: token,
            sessionID: sessionID,
            userID: userID
        ) {
            switch event.step {
            case "start":
                continue
            case "reasoning":
                if let content = event.data?.content {
                    reasoningText += content
                    updateLastMessage(reasoning: reasoningText)
                }
            case "tool_call":
                if let tool = event.data?.tool {
                    let call = ToolCallInfo(
                        id: UUID().uuidString,
                        tool: tool,
                        args: event.data?.args ?? [:],
                        result: nil
                    )
                    toolCalls.append(call)
                    updateLastMessage(toolCalls: toolCalls)
                }
            case "tool_result":
                if let tool = event.data?.tool, let result = event.data?.result {
                    if let index = toolCalls.firstIndex(where: { $0.tool == tool && $0.result == nil }) {
                        toolCalls[index] = ToolCallInfo(
                            id: toolCalls[index].id,
                            tool: tool,
                            args: toolCalls[index].args,
                            result: result
                        )
                    }
                    updateLastMessage(toolCalls: toolCalls)
                }
            case "message":
                if let content = event.data?.content {
                    appendToLastMessage(content)
                }
            case "end":
                finalizeLastMessage()
                isStreaming = false
            case "error":
                if let message = event.data?.message {
                    errorMessage = message
                }
                finalizeLastMessage()
                isStreaming = false
            default:
                break
            }
        }
        isStreaming = false
        self.streamer = nil
    }

    // MARK: - Stop Streaming

    func stopStreaming() {
        streamer?.stop()
        streamer = nil
        isStreaming = false
        if let last = messages.last, last.isStreaming {
            var msg = last
            msg.isStreaming = false
            messages[messages.count - 1] = msg
        }
        // Call DELETE /chat/{id}
        if let projectID = currentProjectID {
            Task {
                try? await apiClient.brainDelete(path: "/chat/\(projectID)") as EmptyResponse
            }
        }
    }

    // MARK: - Human Reply

    func sendHumanReply(reply: String) {
        let msg = ChatMessage(
            id: UUID().uuidString,
            role: .user,
            content: reply,
            timestamp: Date(),
            isStreaming: false
        )
        messages.append(msg)
    }

    // MARK: - File Upload

    func uploadFile(data: Data, filename: String) async {
        do {
            let _ = try await apiClient.uploadFile(data: data, filename: filename)
            // Attach file reference to next message
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private func updateLastMessage(reasoning: String? = nil, toolCalls: [ToolCallInfo]? = nil) {
        guard !messages.isEmpty else { return }
        var msg = messages[messages.count - 1]
        if let reasoning = reasoning { msg.reasoning = reasoning }
        if let toolCalls = toolCalls { msg.toolCalls = toolCalls }
        messages[messages.count - 1] = msg
    }

    private func appendToLastMessage(_ text: String) {
        guard !messages.isEmpty else { return }
        var msg = messages[messages.count - 1]
        msg.content += text
        messages[messages.count - 1] = msg
    }

    private func finalizeLastMessage() {
        guard !messages.isEmpty else { return }
        var msg = messages[messages.count - 1]
        msg.isStreaming = false
        messages[messages.count - 1] = msg
    }

    func clearChat() {
        messages.removeAll()
        currentProjectID = nil
        currentTaskID = nil
        errorMessage = nil
        editingMessageId = nil
        tokenUsage = nil
    }

    // MARK: - Edit Message

    func editMessage(id: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }),
              messages[index].role == .user else { return }
        editingMessageId = id
        currentInput = messages[index].content
    }

    func submitEdit() {
        guard let id = editingMessageId,
              let index = messages.firstIndex(where: { $0.id == id }) else {
            cancelEdit()
            return
        }
        let newContent = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newContent.isEmpty else { return }

        // Remove all messages after the edited one
        if index + 1 < messages.count {
            messages = Array(messages[0...index])
        }

        // Update the message content
        messages[index].content = newContent
        editingMessageId = nil
        currentInput = ""

        // Resend
        guard let projectID = currentProjectID else { return }
        let taskID = UUID().uuidString.lowercased()
        currentTaskID = taskID
        isLoading = true
        Task {
            await sendChatRequest(projectID: projectID, taskID: taskID, question: newContent)
        }
    }

    func cancelEdit() {
        editingMessageId = nil
        currentInput = ""
    }

    // MARK: - Regenerate

    func regenerateLastResponse() {
        guard messages.count >= 2 else { return }
        if messages.last?.role == .assistant {
            messages.removeLast()
        }
        guard let lastUserMsg = messages.last, lastUserMsg.role == .user,
              let projectID = currentProjectID else { return }
        let taskID = UUID().uuidString.lowercased()
        currentTaskID = taskID
        isLoading = true
        Task {
            await sendChatRequest(projectID: projectID, taskID: taskID, question: lastUserMsg.content)
        }
    }

    // MARK: - Share

    var conversationAsText: String {
        messages.map { msg in
            let role = msg.role == .user ? "You" : "Assistant"
            return "\(role): \(msg.content)"
        }.joined(separator: "\n\n")
    }

    var conversationAsMarkdown: String {
        let header = "# Chat Conversation\n\n"
        let body = messages.map { msg in
            let role = msg.role == .user ? "**You**" : "**Assistant**"
            return "\(role):\n\n\(msg.content)"
        }.joined(separator: "\n\n---\n\n")
        return header + body
    }

    func copyConversationAsText() {
        UIPasteboard.general.string = conversationAsText
    }

    func copyConversationAsMarkdown() {
        UIPasteboard.general.string = conversationAsMarkdown
    }

    func shareConversation() {
        guard !messages.isEmpty else { return }
        let text = conversationAsText
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let root = window.rootViewController {
            av.popoverPresentationController?.sourceView = root.view
            root.present(av, animated: true)
        }
    }
}