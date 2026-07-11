import Foundation

@MainActor
final class RemoteControlViewModel: ObservableObject {
    @Published var devices: [RemoteDevice] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    func loadDevices() {
        isLoading = true
        Task {
            do {
                let response: [RemoteDevice] = try await apiClient.apiRequest(
                    method: "GET", path: "/remote-control/devices"
                )
                devices = response
            } catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }

    func pairDevice(name: String, platform: String) async {
        do {
            let body: [String: String] = ["name": name, "platform": platform]
            let _: RemoteDevice = try await apiClient.apiRequest(
                method: "POST", path: "/remote-control/pair", body: body
            )
            await loadDevices()
        } catch { errorMessage = error.localizedDescription }
    }

    func removeDevice(id: String) async {
        do {
            let _: EmptyResponse = try await apiClient.apiRequest(
                method: "DELETE", path: "/remote-control/device/\(id)"
            )
            await loadDevices()
        } catch { errorMessage = error.localizedDescription }
    }

    func sendCommand(deviceId: String, command: String, params: [String: String]?) async {
        do {
            let body = RemoteCommand(deviceId: deviceId, command: command, params: params)
            let _: EmptyResponse = try await apiClient.apiRequest(
                method: "POST", path: "/remote-control/command", body: body
            )
        } catch { errorMessage = error.localizedDescription }
    }
}