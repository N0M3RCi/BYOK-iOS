import Foundation

@MainActor
final class ChannelsViewModel: ObservableObject {
    @Published var channels: [Channel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    func loadChannels() {
        isLoading = true
        Task {
            do {
                let response: [Channel] = try await apiClient.brainGet(path: "/channels")
                channels = response
            } catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }

    func toggleChannel(_ channel: Channel) async {
        do {
            let body: [String: AnyEncodable] = [
                "enabled": AnyEncodable(!channel.enabled)
            ]
            let _: Channel = try await apiClient.brainPut(path: "/channels/\(channel.id)", body: body)
            loadChannels()
        } catch { errorMessage = error.localizedDescription }
    }

    func createChannel(name: String, type: String) async {
        do {
            let body: [String: String] = ["name": name, "type": type]
            let _: Channel = try await apiClient.brainPost(path: "/channels", body: body)
            loadChannels()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteChannel(id: String) async {
        do {
            let _: EmptyResponse = try await apiClient.brainDelete(path: "/channels/\(id)")
            loadChannels()
        } catch { errorMessage = error.localizedDescription }
    }
}
