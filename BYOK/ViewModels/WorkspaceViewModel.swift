import Foundation

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPath = ""
    @Published var showFilePicker = false

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

    func uploadFile(data: Data, filename: String, projectID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let _ = try await apiClient.uploadFile(data: data, filename: filename)
            loadFiles(projectID: projectID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}