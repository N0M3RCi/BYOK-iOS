import Foundation

@MainActor
final class ToolsViewModel: ObservableObject {
    @Published var tools: [Tool] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    func loadTools() {
        isLoading = true
        Task {
            do {
                let response: [Tool] = try await apiClient.brainGet(path: "/tools")
                tools = response
            } catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }

    func installTool(name: String) async {
        do {
            let _: Tool = try await apiClient.brainPost(path: "/tools/\(name)/install")
            loadTools()
        } catch { errorMessage = error.localizedDescription }
    }

    func removeTool(name: String) async {
        do {
            let _: EmptyResponse = try await apiClient.brainDelete(path: "/tools/\(name)")
            loadTools()
        } catch { errorMessage = error.localizedDescription }
    }

    func getOAuthURL(name: String) async -> String? {
        do {
            let response: [String: String] = try await apiClient.brainGet(path: "/tools/\(name)/oauth/url")
            return response["url"]
        } catch { return nil }
    }
}