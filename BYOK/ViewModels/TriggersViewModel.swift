import Foundation

@MainActor
final class TriggersViewModel: ObservableObject {
    @Published var triggers: [Trigger] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    func loadTriggers() {
        isLoading = true
        Task {
            do {
                let response: [Trigger] = try await apiClient.apiRequest(method: "GET", path: "/trigger")
                triggers = response
            } catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }

    func createTrigger(name: String, type: String, config: TriggerConfig?) async {
        do {
            let body: [String: AnyEncodable] = [
                "name": AnyEncodable(name),
                "type": AnyEncodable(type),
                "config": AnyEncodable(config ?? TriggerConfig(schedule: nil, webhookUrl: nil, slackChannel: nil))
            ]
            let _: Trigger = try await apiClient.apiRequest(method: "POST", path: "/trigger", body: body)
            await loadTriggers()
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleTrigger(_ trigger: Trigger) async {
        do {
            let body: [String: Bool] = ["enabled": !trigger.enabled]
            let _: Trigger = try await apiClient.apiRequest(
                method: "PUT", path: "/trigger/\(trigger.id)", body: body
            )
            await loadTriggers()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteTrigger(_ id: String) async {
        do {
            let _: EmptyResponse = try await apiClient.apiRequest(method: "DELETE", path: "/trigger/\(id)")
            await loadTriggers()
        } catch { errorMessage = error.localizedDescription }
    }

    func executeTrigger(_ id: String) async {
        do {
            let _: EmptyResponse = try await apiClient.apiRequest(
                method: "POST", path: "/trigger/\(id)/execute"
            )
        } catch { errorMessage = error.localizedDescription }
    }
}