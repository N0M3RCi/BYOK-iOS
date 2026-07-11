import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var recentSpaces: [Space] = []
    @Published var recentProjects: [HistoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    func loadDashboard() {
        isLoading = true
        errorMessage = nil
        Task {
            await loadSpaces()
            await loadRecentProjects()
            isLoading = false
        }
    }

    private func loadSpaces() async {
        do {
            let response: [Space] = try await apiClient.apiRequest(method: "GET", path: "/space")
            recentSpaces = response
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadRecentProjects() async {
        do {
            let response: PaginatedResponse<HistoryItem> = try await apiClient.apiRequest(
                method: "GET",
                path: "/chat/history?page=1&page_size=10"
            )
            recentProjects = response.items
        } catch {
            // Not critical
        }
    }

    func createSpace(name: String) async {
        do {
            let body: [String: String] = ["name": name]
            let _: Space = try await apiClient.apiRequest(method: "POST", path: "/space", body: body)
            await loadSpaces()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}