import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPath = ""

    private let apiClient = APIClient.shared
    private let keychain = KeychainManager.shared

    func loadFiles(projectID: String) {
        isLoading = true
        Task {
            do {
                let email = keychain.getEmail() ?? ""
                let response: [FileItem] = try await apiClient.brainGet(
                    path: "/files?project_id=\(projectID)&email=\(email)"
                )
                files = response
            } catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }

    func deleteFile(filename: String, projectID: String) async {
        do {
            let email = keychain.getEmail() ?? ""
            let _: EmptyResponse = try await apiClient.brainDelete(
                path: "/files/\(filename)?project_id=\(projectID)&email=\(email)"
            )
            files.removeAll { $0.filename == filename }
        } catch { errorMessage = error.localizedDescription }
    }
}