import Foundation

@MainActor
final class ActivityLogsViewModel: ObservableObject {
    @Published var logs: [ActivityLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    func loadAllLogs() {
        isLoading = true
        Task {
            do {
                let response: [ActivityLog] = try await apiClient.brainGet(path: "/activity-logs")
                logs = response
            } catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }

    func loadLogs(triggerId: String) {
        isLoading = true
        Task {
            do {
                let response: [ActivityLog] = try await apiClient.brainGet(path: "/activity-logs/trigger/\(triggerId)")
                logs = response
            } catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }
}
