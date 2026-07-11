You are building a native iOS app that is an exact replica of the M3RCI - UniMind web application. It's an AI-powered multi-agent workforce platform. Users can chat with AI agents, manage projects, configure models, install skills and MCP tools, manage files, and control AI agent workflows. The iOS app must have identical functionality and API integration as the web app.

The app communicates with two backend services running on a VPS at class.n0m3rci.cc:
1. Brain Service (proxied via nginx at class.n0m3rci.cc) - handles AI chat, tasks, models, files, skills, MCP, tools, workspace, remote sub-agents
2. API Server (proxied at class.n0m3rci.cc/api/) - handles auth, users, chat history, providers, triggers, spaces, remote control

Build a production-ready iOS app using SwiftUI, targeting iOS 16+. Use MVVM architecture with async/await networking. Store auth tokens in Keychain. Use Core Data or SwiftData for local caching.

---

## AUTHENTICATION

Two auth systems. The frontend gets a JWT from the API Server login, then uses that Bearer token for all Brain Service requests too.

API Server auth:
- POST /api/v1/user/login -> { email, password } -> { code, text, token, email, user_id, role }
- POST /api/v1/user/auto-login -> {} -> same response (for restoring session on app launch)
- POST /api/v1/user/sign-up -> { email, password, confirm_password }
- POST /api/v1/user/logout -> invalidates token
- PUT /api/v1/user/password -> { old_password, new_password }
- POST /api/v1/user/passcode -> set passcode
- PUT /api/v1/user/passcode -> update passcode
- DELETE /api/v1/user/passcode -> remove passcode

Error codes: code=0 success, code=10 login failed, other non-zero = error with `text` field. HTTP 401 -> redirect to login.

Brain Service auth headers on every request:
- Authorization: Bearer <token>
- X-Channel: ios
- X-Session-ID: <uuid>
- X-User-ID: <user_id>

---

## SCREENS TO BUILD

### 1. Login Screen
- Auto-login check on launch (call auto-login with stored token)
- Email/password fields with login button
- Sign-up link
- App title "M3RCI - UniMind" with styling

### 2. Sign Up Screen
- Email, password, confirm password fields
- Registration form with validation

### 3. Passcode Gate
- 4-6 digit numeric passcode entry
- Face ID / Touch ID option
- Create, change, remove passcode flows

### 4. Home Dashboard
- Recent projects list
- Quick action buttons (New Chat, Settings, etc.)
- Space navigation/switcher
- Trigger status widget
- Navigation to all screens

### 5. Chat Screen (the core feature)
This is the main chat interface. It must handle SSE streaming from the Brain Service.

POST /chat -> starts a chat session and returns an SSE stream:
```
data: {"step":"start","data":{...}}
data: {"step":"reasoning","data":{"content":"thinking..."}}
data: {"step":"tool_call","data":{"tool":"name","args":{...}}}
data: {"step":"tool_result","data":{"tool":"name","result":"..."}}
data: {"step":"message","data":{"content":"response","agent":"name"}}
data: {"step":"end","data":{"task_id":"..."}}
data: {"step":"error","data":{"message":"error text"}}
: heartbeat\n\n  (every 15 seconds)
```

Chat request body:
{
  "task_id": "<uuid>",
  "project_id": "<project-id>",
  "question": "user message",
  "email": "user@example.com",
  "model_platform": "OPENAI",
  "model_type": "GPT_4O_MINI",
  "api_key": "sk-...",
  "api_url": null,
  "language": "en",
  "session_mode": "workforce",
  "user_id": "<user_id>",
  "server_url": "https://class.n0m3rci.cc/v1",
  "attaches": []
}

Chat UI requirements:
- Message bubbles (user left-aligned, AI right-aligned)
- Styling: user messages blue/gray, AI messages dark/white based on theme
- Streaming text with typewriter effect (append SSE message chunks)
- Show AI reasoning steps (expandable "thinking" section)
- Show tool calls (expandable "tools used" section)
- File attachment button (opens iOS document picker / photo picker)
- Stop button (cancels the SSE stream and calls DELETE /chat/{id})
- Human reply input (when AI asks for clarification)
- Task list sidebar (shows workforce sub-tasks)
- Model selector dropdown

Follow-up messages:
- POST /chat/{project_id} -> continue conversation with { question, task_id: <new-uuid> }
- DELETE /chat/{id} -> stop running session
- GET /chat/{project_id}/status -> check if session is running/done

File upload:
- POST /files (multipart form with "file", header X-Session-ID: <session_id>)
- Returns { file_id: "upload://filename_timestamp", filename, size }
- Max 50MB per file, 20 files per session

### 6. Settings Screen (tab-based)
a) General - Language picker (English, Chinese, Japanese, Korean, French, German, Spanish, Arabic, Russian, Italian), Theme (light/dark/system), Font size
b) Models - Model provider list (OpenAI, Azure, Anthropic, Google, custom), API key management, Model picker (GPT-4o, GPT-4o-mini, Claude, Gemini, etc.), Custom API URL, Model validation test button
c) API - Brain endpoint URL config (default), Connection status indicator
d) Privacy - Data settings, privacy policy, terms, export data
e) Students (admin) - User management, usage limits

Use GET /api/v1/config and PUT /api/v1/config for settings persistence.

### 7. Agents Screen
- List of configured agents
- Create/edit agent: name, description, tools assigned, MCP tools, custom model override
- Agent memory settings
- Each agent can have custom model config: { model_platform, model_type, api_key, api_url, extra_params }

Skills management:
- GET /skills -> list all skills [{ name, description, path, scope, skillDirName, isExample }]
- GET /skills/{dirName} -> read skill content (markdown)
- POST /skills/{dirName} -> create/update skill with content
- DELETE /skills/{dirName} -> delete skill
- POST /skills/import -> import from .zip
- Skills config: GET/PUT/DELETE /skills/config/{skill_name}, POST toggle

MCP Management:
- GET /mcp/list -> { mcpServers: { name: { command, args, env } } }
- POST /mcp/install -> { name, mcp: { command, args, env } }
- DELETE /mcp/{name} -> remove
- PUT /mcp/{name} -> update

### 8. Tools Screen
- List of 30+ tools/integrations (Google Calendar, LinkedIn, Notion, Slack, GitHub, Twitter, Gmail, Google Drive, WhatsApp, Search, Code Execution, Browser, File System, Terminal, etc.)
- GET /tools -> list tools
- POST /tools/{name}/install -> configure with auth
- DELETE /tools/{name} -> remove
- OAuth flow for tools that need it

### 9. Workspace / Files Screen
- File browser for project working directory
- GET /files?project_id=&email= -> list files [{ filename, url, relativePath }]
- File preview (images, code with syntax highlighting, markdown, PDF)
- Swipe to delete
- Folder navigation

### 10. History Screen
- Chat history list from GET /api/v1/chat/history?page=&page_size=
- GET /api/v1/chat/history/grouped -> grouped by date
- GET /api/v1/chat/history/{id} -> detail with messages
- DELETE /api/v1/chat/history/{id}
- Search/filter
- Share chat via POST /api/v1/chat/share

### 11. Admin Users Screen
- GET /api/v1/admin/users -> list all users
- User management (edit roles, delete)
- Admin-only access

### 12. Triggers Screen
- GET /api/v1/trigger -> list triggers [{ id, name, type: "schedule"|"webhook"|"slack", enabled, config }]
- POST/PUT/DELETE /api/v1/trigger
- POST /api/v1/trigger/{id}/execute -> manual run
- Trigger configuration forms

### 13. Remote Control Screen
- GET /api/v1/remote-control/devices -> list paired devices
- POST /api/v1/remote-control/pair -> pair new device
- DELETE /api/v1/remote-control/device/{id}
- POST /api/v1/remote-control/command -> send command
- Screen sharing UI

---

## SSE STREAMING IMPLEMENTATION (most critical iOS detail)

Use URLSession with URLSessionAsyncBytes for streaming SSE:

```swift
let request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
request.httpBody = try JSONEncoder().encode(chatRequest)

let (bytes, response) = try await URLSession.shared.bytes(for: request)

var currentEvent = ""
for try await line in bytes.lines {
    if line.hasPrefix("data: ") {
        currentEvent = String(line.dropFirst(6))
    } else if line.isEmpty && !currentEvent.isEmpty {
        // Empty line = end of event, parse the JSON
        let data = currentEvent.data(using: .utf8)!
        let event = try JSONDecoder().decode(SSEEvent.self, from: data)
        handleEvent(event)
        currentEvent = ""
    }
}
```

Parse events by "step" field and handle each type:
- "start" -> initialize UI state
- "reasoning" -> append to reasoning text
- "tool_call" -> show tool call in UI
- "tool_result" -> show tool result
- "message" -> append to response text (streaming)
- "end" -> finalize, close stream
- "error" -> show error state

Timeout: 60 minutes. Heartbeat every 15 seconds (line starting with ":").

---

## DATA MODELS (Swift)

```swift
enum UserRole: String, Codable { case user, admin }
enum SessionStatus: String, Codable { case running, done, confirming, paused, offline }
enum ModelPlatform: String, Codable { case OPENAI, AZURE, ANTHROPIC, GOOGLE, CUSTOM }
struct User: Codable { let id: Int; let email: String; let role: UserRole }
struct ChatRequest: Codable { let taskId, projectId, question, email: String; let modelPlatform: ModelPlatform; let modelType, apiKey: String; let apiUrl: String?; let language: String; let sessionMode: String; let userId: String; let serverUrl: String; let attaches: [String] }
struct ChatStatus: Codable { let projectId: String; let hasLock: Bool; let status: SessionStatus; let currentTaskId: String? }
struct SSEEvent: Codable { let step: String; let data: SSEEventData? }
struct SSEEventData: Codable { let content: String?; let taskId: String?; let tool: String?; let args: [String: AnyCodable]?; let result: String?; let agent: String?; let message: String? }
struct Space: Codable, Identifiable { let id, name, type: String; let rootPath: String?; let createdAt: String; let projectCount: Int }
struct HistoryItem: Codable, Identifiable { let id: String; let projectId: String?; let title: String?; let createdAt: String }
struct Trigger: Codable, Identifiable { let id, name, type: String; let enabled: Bool }
struct Skill: Codable, Identifiable { let name, description, path, scope, skillDirName: String; let isExample: Bool; var enabled: Bool }
struct MCPServer: Codable, Identifiable { let name, command: String; let args: [String]; let env: [String: String]; var id: String { name } }
struct Agent: Codable, Identifiable { let name, description: String; let tools: [String]; let customModelConfig: ModelConfig?; var id: String { name } }
struct ModelConfig: Codable { let platform: ModelPlatform?; let modelType, apiKey, apiUrl: String? }
struct ModelValidationResult: Codable { let isValid: Bool; let error: String?; let message: String?; let successfulStages: [String]? }
struct FileItem: Codable, Identifiable { let filename: String; let url: String; let relativePath: String; var id: String { filename } }
struct LoginResponse: Codable { let code: Int; let text: String?; let token: String?; let email: String?; let userId: Int?; let role: String? }
```

---

## API ENDPOINT SUMMARY (all endpoints needed)

Brain Service:
POST /chat, POST /chat/{id}, PUT /chat/{id}, DELETE /chat/{id}, GET /chat/{id}/status
POST /chat/{id}/human-reply, POST /chat/{id}/install-mcp, POST /chat/{id}/add-task
DELETE /chat/{projectId}/remove-task/{taskId}, POST /chat/{projectId}/skip-task
POST /files, GET /files, GET /files/stream, GET /files/preview/{email}/{projectId}/{path}
GET /skills, GET/POST/DELETE /skills/{dir}, POST /skills/import, GET /skills/{dir}/files
GET/POST/PUT/DELETE /skills/config, POST /skills/config/{name}/toggle
GET /mcp/list, POST /mcp/install, DELETE /mcp/{name}, PUT /mcp/{name}
GET /tools, GET/POST/DELETE /tools/{name}, GET /tools/{name}/oauth/url, POST /tools/{name}/oauth/callback
GET /workspace/capabilities, GET /workspace/current, POST /workspace/bind, POST /workspace/scratch, DELETE /workspace/{spaceId}
GET /remote-sub-agent/providers, POST /remote-sub-agent/providers/validate
POST /model/validate, POST /task/{id}/start, PUT /task/{id}, PUT /task/{id}/take-control, POST /task/{id}/add-agent, DELETE /task/stop-all

API Server (prefix /api/v1):
POST /user/login, POST /user/auto-login, POST /user/sign-up, POST /user/logout, PUT /user/password
POST/PUT/DELETE /user/passcode
GET/PUT /user/info, GET /user/credits
GET /admin/users, PUT/DELETE /admin/users/{id}
GET/POST/PUT/DELETE /chat/history, GET /chat/history/grouped
POST/DELETE /chat/share, POST/GET /chat/snapshot, GET /chat/step/{projectId}
GET/PUT /config, GET /config/plan
GET/POST/PUT/DELETE /provider
GET/POST/PUT/DELETE /space, POST /space/{id}/sync
GET/POST/PUT/DELETE /trigger, POST /trigger/{id}/execute
POST /trigger/webhook/{token}, POST /trigger/slack/events, GET /trigger/slack/install
GET/POST/DELETE /remote-control/devices, POST /remote-control/pair, POST /remote-control/command
GET/POST/DELETE /oauth/{provider}
GET /demo/status, POST /demo/start, POST /demo/stop
GET /health, GET /mcp/category, GET/POST/PUT/DELETE /mcp/user

---

## STYLING & THEMING

The web app uses a dark theme with accent colors. For iOS:
- Dark mode + light mode support (follow system setting by default)
- Accent color: use a blue/teal tone
- Chat bubbles: user = accent color, AI = system background with border
- Cards/panels: use system grouped background
- Navigation: standard iOS navigation with large titles
- Icons: SF Symbols throughout
- Smooth animations for message streaming

---

## NAVIGATION STRUCTURE

Tab bar with:
1. Home (house icon) -> Dashboard + Recent Projects
2. Chat (message icon) -> Active chat or new chat
3. Agents (person icon) -> Agent list + Skills + Tools
4. History (clock icon) -> Chat history
5. Settings (gear icon) -> Settings tabs

Modal screens: Login, Sign-up, Passcode, File preview, Model config, Trigger config

Navigation links from Home: Space details, Project details, Admin panel, Remote control

---

## WHAT TO BUILD

Build a COMPLETE, runnable Xcode project. Every screen listed above must be functional. Every API endpoint must be wired up. The app must compile and run against the live backend at class.n0m3rci.cc.

The final deliverable is a full Xcode project with:
- All SwiftUI views for every screen
- All networking (API client, SSE streaming, file upload)
- Auth flow (login, token storage, auto-login, passcode, biometrics)
- Real-time chat with streaming responses
- Settings persistence
- File management
- All API integrations
- Dark/light theme support
- Multi-language i18n support (English, Chinese, Japanese, Korean, French, German, Spanish, Arabic, Russian, Italian)
