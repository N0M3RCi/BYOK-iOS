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
    @Published var selectedModel: ModelType = .GPT_4O_MINI
    @Published var selectedPlatform: ModelPlatform = .OPENAI
    @Published var currentProjectID: String?
    @Published var currentTaskID: String?
    @Published var showReasoning = false
    @Published var attachedFiles: [String] = []
    @Published var attachedKnowledgeBaseIds: [String] = []

    private let apiClient = APIClient.shared
    private let keychain = KeychainManager.shared
    private var streamer: SSEStreamer?

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

        let request = ChatRequest(
            taskId: taskID,
            projectId: projectID,
            question: question,
            email: email,
            modelPlatform: selectedPlatform.rawValue,
            modelType: selectedModel.rawValue,
            apiKey: "",
            apiUrl: nil,
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
    }

    // MARK: - Model Provider/Type Helpers

    var availableModels: [ModelType] {
        ModelType.allCases
    }

    var availablePlatforms: [ModelPlatform] {
        ModelPlatform.allCases
    }

    var modelDisplayName: String {
        "\(selectedPlatform.displayName) - \(selectedModel.displayName)"
    }
}