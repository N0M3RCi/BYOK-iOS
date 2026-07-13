import Foundation

@MainActor
final class AgentsViewModel: ObservableObject {
    @Published var agents: [Agent] = []
    @Published var skills: [Skill] = []
    @Published var mcpServers: [MCPServer] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showImportSkill = false
    @Published var showInstallMCP = false
    @Published var newMCPName = ""
    @Published var newMCPCommand = ""
    @Published var newMCPArgs = ""

    private let apiClient = APIClient.shared

    func loadAll() {
        isLoading = true
        errorMessage = nil
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.fetchAgents() }
                group.addTask { await self.fetchSkills() }
                group.addTask { await self.fetchMCPServers() }
            }
            isLoading = false
        }
    }

    private func fetchAgents() async {
        do {
            let response: [Agent] = try await apiClient.brainGet(path: "/agents")
            agents = response
        } catch { errorMessage = error.localizedDescription }
    }

    private func fetchSkills() async {
        do {
            let response: [Skill] = try await apiClient.brainGet(path: "/skills")
            skills = response
        } catch { /* non-critical */ }
    }

    private func fetchMCPServers() async {
        do {
            let response = try await apiClient.brainGet(path: "/mcp/list") as [String: [String: MCPServer]]
            mcpServers = response["mcpServers"]?.map { $0.value } ?? []
        } catch { /* non-critical */ }
    }

    func createAgent(name: String, description: String, tools: [String]) async {
        do {
            let body: [String: AnyEncodable] = [
                "name": AnyEncodable(name),
                "description": AnyEncodable(description),
                "tools": AnyEncodable(tools)
            ]
            let _: Agent = try await apiClient.brainPost(path: "/agents", body: body)
            await fetchAgents()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveAgent(_ agent: Agent) async {
        do {
            let _: Agent = try await apiClient.brainPut(path: "/agents/\(agent.name)", body: agent)
            await fetchAgents()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteAgent(name: String) async {
        do {
            let _: EmptyResponse = try await apiClient.brainDelete(path: "/agents/\(name)")
            await fetchAgents()
        } catch { errorMessage = error.localizedDescription }
    }
}