import Foundation

@MainActor
final class AdminViewModel: ObservableObject {
    @Published var users: [AdminUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    func loadUsers() {
        isLoading = true
        Task {
            do {
                let response: [AdminUser] = try await apiClient.apiRequest(method: "GET", path: "/admin/users")
                users = response
            } catch { errorMessage = error.localizedDescription }
            isLoading = false
        }
    }

    func updateUserRole(id: Int, role: String) async {
        do {
            let body: [String: String] = ["role": role]
            let _: AdminUser = try await apiClient.apiRequest(
                method: "PUT", path: "/admin/users/\(id)", body: body
            )
            loadUsers()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteUser(id: Int) async {
        do {
            let _: EmptyResponse = try await apiClient.apiRequest(
                method: "DELETE", path: "/admin/users/\(id)"
            )
            loadUsers()
        } catch { errorMessage = error.localizedDescription }
    }
}