import Foundation

// MARK: - Enums
enum UserRole: String, Codable, Equatable {
    case user, admin
}

enum SessionStatus: String, Codable, Equatable {
    case running, done, confirming, paused, offline
}

enum ModelPlatform: String, Codable, CaseIterable, Equatable {
    case OPENAI, AZURE, ANTHROPIC, GOOGLE, CUSTOM

    var displayName: String {
        switch self {
        case .OPENAI: return "OpenAI"
        case .AZURE: return "Azure"
        case .ANTHROPIC: return "Anthropic"
        case .GOOGLE: return "Google"
        case .CUSTOM: return "Custom"
        }
    }
}

enum ModelType: String, Codable, CaseIterable, Equatable {
    case GPT_4O = "GPT_4O"
    case GPT_4O_MINI = "GPT_4O_MINI"
    case CLAUDE_3_5_SONNET = "CLAUDE_3_5_SONNET"
    case CLAUDE_3_5_HAIKU = "CLAUDE_3_5_HAIKU"
    case GEMINI_PRO = "GEMINI_PRO"
    case GEMINI_FLASH = "GEMINI_FLASH"

    var displayName: String {
        switch self {
        case .GPT_4O: return "GPT-4o"
        case .GPT_4O_MINI: return "GPT-4o Mini"
        case .CLAUDE_3_5_SONNET: return "Claude 3.5 Sonnet"
        case .CLAUDE_3_5_HAIKU: return "Claude 3.5 Haiku"
        case .GEMINI_PRO: return "Gemini Pro"
        case .GEMINI_FLASH: return "Gemini Flash"
        }
    }
}

enum TriggerType: String, Codable, Equatable {
    case schedule, webhook, slack
}

enum AppLanguage: String, CaseIterable, Equatable {
    case en = "en"
    case zh = "zh"
    case ja = "ja"
    case ko = "ko"
    case fr = "fr"
    case de = "de"
    case es = "es"
    case ar = "ar"
    case ru = "ru"
    case it = "it"

    var displayName: String {
        switch self {
        case .en: return "English"
        case .zh: return "中文"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .ar: return "العربية"
        case .ru: return "Русский"
        case .it: return "Italiano"
        }
    }
}

enum AppTheme: String, CaseIterable, Equatable {
    case system, light, dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

// MARK: - Auth Models
struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct SignUpRequest: Codable {
    let email: String
    let password: String
    let confirmPassword: String

    enum CodingKeys: String, CodingKey {
        case email, password
        case confirmPassword = "confirm_password"
    }
}

struct LoginResponse: Codable {
    let code: Int
    let text: String?
    let token: String?
    let email: String?
    let userId: Int?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case code, text, token, email
        case userId = "user_id"
        case role
    }
}

struct PasswordChangeRequest: Codable {
    let oldPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case oldPassword = "old_password"
        case newPassword = "new_password"
    }
}

struct PasscodeRequest: Codable {
    let passcode: String
}

// MARK: - User
struct User: Codable, Equatable {
    let id: Int
    let email: String
    let role: UserRole
}

// MARK: - Chat Models
struct ChatRequest: Codable {
    let taskId: String
    let projectId: String
    let question: String
    let email: String
    let modelPlatform: String
    let modelType: String
    let apiKey: String
    let apiUrl: String?
    let language: String
    let sessionMode: String
    let userId: String
    let serverUrl: String
    let attaches: [String]

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case projectId = "project_id"
        case question, email
        case modelPlatform = "model_platform"
        case modelType = "model_type"
        case apiKey = "api_key"
        case apiUrl = "api_url"
        case language
        case sessionMode = "session_mode"
        case userId = "user_id"
        case serverUrl = "server_url"
        case attaches
    }
}

struct ChatStatus: Codable, Equatable {
    let projectId: String
    let hasLock: Bool
    let status: SessionStatus
    let currentTaskId: String?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case hasLock = "has_lock"
        case status
        case currentTaskId = "current_task_id"
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let role: MessageRole
    let content: String
    let timestamp: Date
    var reasoning: String?
    var toolCalls: [ToolCallInfo]?
    var isStreaming: Bool

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.role == rhs.role &&
        lhs.content == rhs.content &&
        lhs.isStreaming == rhs.isStreaming
    }
}

enum MessageRole: Equatable {
    case user
    case assistant
    case system
}

struct ToolCallInfo: Identifiable, Equatable {
    let id: String
    let tool: String
    let args: [String: JSONValue]
    let result: String?
}

// MARK: - SSE Event
struct SSEEvent: Codable {
    let step: String
    let data: SSEEventData?
}

struct SSEEventData: Codable {
    let content: String?
    let taskId: String?
    let tool: String?
    let args: [String: JSONValue]?
    let result: String?
    let agent: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case content, tool, args, result, agent, message
        case taskId = "task_id"
    }
}

// MARK: - Space
struct Space: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let type: String
    let rootPath: String?
    let createdAt: String
    let projectCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case rootPath = "root_path"
        case createdAt = "created_at"
        case projectCount = "project_count"
    }
}

// MARK: - History
struct HistoryItem: Codable, Identifiable, Equatable {
    let id: String
    let projectId: String?
    let title: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case title
        case createdAt = "created_at"
    }
}

struct HistoryGroup: Identifiable, Equatable {
    let id: String
    let date: Date
    let items: [HistoryItem]
}

// MARK: - Trigger
struct Trigger: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let type: String
    let enabled: Bool
    let config: TriggerConfig?

    enum CodingKeys: String, CodingKey {
        case id, name, type, enabled, config
    }
}

struct TriggerConfig: Codable, Equatable {
    let schedule: String?
    let webhookUrl: String?
    let slackChannel: String?

    enum CodingKeys: String, CodingKey {
        case schedule
        case webhookUrl = "webhook_url"
        case slackChannel = "slack_channel"
    }
}

// MARK: - Skill
struct Skill: Codable, Identifiable, Equatable {
    let name: String
    let description: String
    let path: String
    let scope: String
    let skillDirName: String
    let isExample: Bool
    var enabled: Bool

    var id: String { skillDirName }

    enum CodingKeys: String, CodingKey {
        case name, description, path, scope
        case skillDirName = "skillDirName"
        case isExample = "isExample"
        case enabled
    }
}

// MARK: - MCP
struct MCPServer: Codable, Identifiable, Equatable {
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]

    var id: String { name }
}

struct MCPInstallRequest: Codable {
    let name: String
    let mcp: MCPConfig
}

struct MCPConfig: Codable {
    let command: String
    let args: [String]
    let env: [String: String]
}

// MARK: - Agent
struct Agent: Codable, Identifiable, Equatable {
    let name: String
    let description: String
    let tools: [String]
    let mcpTools: [String]?
    let customModelConfig: ModelConfig?
    let memorySettings: AgentMemorySettings?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, description, tools
        case mcpTools = "mcp_tools"
        case customModelConfig = "custom_model_config"
        case memorySettings = "memory_settings"
    }
}

struct AgentMemorySettings: Codable, Equatable {
    let enabled: Bool
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case enabled
        case maxTokens = "max_tokens"
    }
}

// MARK: - Model Config
struct ModelConfig: Codable, Equatable {
    let platform: String?
    let modelType: String?
    let apiKey: String?
    let apiUrl: String?
    let extraParams: [String: String]?

    enum CodingKeys: String, CodingKey {
        case platform
        case modelType = "model_type"
        case apiKey = "api_key"
        case apiUrl = "api_url"
        case extraParams = "extra_params"
    }
}

struct ModelValidationResult: Codable, Equatable {
    let isValid: Bool
    let error: String?
    let message: String?
    let successfulStages: [String]?

    enum CodingKeys: String, CodingKey {
        case isValid = "is_valid"
        case error, message
        case successfulStages = "successful_stages"
    }
}

// MARK: - File
struct FileItem: Codable, Identifiable, Equatable {
    let filename: String
    let url: String
    let relativePath: String

    var id: String { filename }
}

struct FileUploadResponse: Codable, Equatable {
    let fileId: String
    let filename: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case filename, size
    }
}

// MARK: - Tool
struct Tool: Codable, Identifiable, Equatable {
    let name: String
    let description: String
    let installed: Bool
    let authRequired: Bool

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, description, installed
        case authRequired = "auth_required"
    }
}

// MARK: - Remote Control
struct RemoteDevice: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let platform: String
    let lastSeen: String?

    enum CodingKeys: String, CodingKey {
        case id, name, platform
        case lastSeen = "last_seen"
    }
}

struct RemoteCommand: Codable {
    let deviceId: String
    let command: String
    let params: [String: String]?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case command, params
    }
}

// MARK: - Config
struct AppConfig: Codable, Equatable {
    let language: String?
    let theme: String?
    let fontSize: Int?
    let brainEndpoint: String?
    let modelPlatform: String?
    let modelType: String?
    let apiKey: String?
    let apiUrl: String?

    enum CodingKeys: String, CodingKey {
        case language, theme
        case fontSize = "font_size"
        case brainEndpoint = "brain_endpoint"
        case modelPlatform = "model_platform"
        case modelType = "model_type"
        case apiKey = "api_key"
        case apiUrl = "api_url"
    }
}

// MARK: - Admin
struct AdminUser: Codable, Identifiable, Equatable {
    let id: Int
    let email: String
    let role: String
    let createdAt: String?
    let usageLimit: Int?

    enum CodingKeys: String, CodingKey {
        case id, email, role
        case createdAt = "created_at"
        case usageLimit = "usage_limit"
    }
}

// MARK: - Provider
struct Provider: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let platform: String
    let apiKey: String?
    let apiUrl: String?
    let isActive: Bool

    var providerId: String { id }

    enum CodingKeys: String, CodingKey {
        case id, name, platform
        case apiKey = "api_key"
        case apiUrl = "api_url"
        case isActive = "is_active"
    }
}

// MARK: - Paginated Response
struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let total: Int
    let page: Int
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case items, total, page
        case pageSize = "page_size"
    }
}

// MARK: - Generic API Response
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let text: String?
    let data: T?
}

struct EmptyResponse: Codable {}

// MARK: - Activity Log
struct ActivityLog: Codable, Identifiable, Equatable {
    let id: String
    let action: String
    let description: String?
    let resourceType: String?
    let resourceId: String?
    let userId: String?
    let userEmail: String?
    let createdAt: String
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id, action, description
        case resourceType = "resource_type"
        case resourceId = "resource_id"
        case userId = "user_id"
        case userEmail = "user_email"
        case createdAt = "created_at"
        case metadata
    }
}

// MARK: - Channel
struct Channel: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let type: String?
    let description: String?
    let memberCount: Int?
    let createdAt: String?
    let lastActivityAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, type, description
        case memberCount = "member_count"
        case createdAt = "created_at"
        case lastActivityAt = "last_activity_at"
    }
}

// MARK: - Project
struct Project: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String?
    let status: String?
    let spaceId: String?
    let spaceName: String?
    let taskCount: Int?
    let createdAt: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case spaceId = "space_id"
        case spaceName = "space_name"
        case taskCount = "task_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - ProjectSpace
struct ProjectSpace: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let type: String?
    let rootPath: String?
    let projectCount: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case rootPath = "root_path"
        case projectCount = "project_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Remote SubAgent Provider
final class RemoteSubAgentProvider: ObservableObject, @unchecked Sendable {
    static let shared = RemoteSubAgentProvider()

    @Published var availableAgents: [Agent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    private init() {}

    func fetchAgents() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let agents: [Agent] = try await apiClient.brainGet(path: "/agents")
            await MainActor.run { availableAgents = agents }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func createAgent(name: String, description: String, tools: [String]) async -> Agent? {
        do {
            let body: [String: AnyEncodable] = [
                "name": AnyEncodable(name),
                "description": AnyEncodable(description),
                "tools": AnyEncodable(tools)
            ]
            let agent: Agent = try await apiClient.brainPost(path: "/agents", body: body)
            await fetchAgents()
            return agent
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return nil
        }
    }
}

// MARK: - Task Execution
struct TaskExecution: Codable, Identifiable, Equatable {
    let id: String
    let taskId: String
    let projectId: String?
    let status: String
    let result: String?
    let agent: String?
    let startedAt: String?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, result, agent
        case taskId = "task_id"
        case projectId = "project_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}