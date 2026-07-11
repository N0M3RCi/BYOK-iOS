import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var items: [HistoryItem] = []
    @Published var groupedItems: [HistoryGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    private let apiClient = APIClient.shared
    private var currentPage = 1
    private var hasMore = true

    func loadHistory() {
        isLoading = true
        errorMessage = nil
        Task {
            await fetchHistory()
            await fetchGrouped()
            isLoading = false
        }
    }

    func loadMore() {
        guard hasMore && !isLoading else { return }
        currentPage += 1
        Task {
            await fetchHistory()
        }
    }

    private func fetchHistory() async {
        do {
            let response: PaginatedResponse<HistoryItem> = try await apiClient.apiRequest(
                method: "GET",
                path: "/chat/history?page=\(currentPage)&page_size=20"
            )
            if currentPage == 1 {
                items = response.items
            } else {
                items += response.items
            }
            hasMore = response.items.count == 20
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchGrouped() async {
        do {
            let response: [String: [HistoryItem]] = try await apiClient.apiRequest(
                method: "GET",
                path: "/chat/history/grouped"
            )
            groupedItems = response.compactMap { key, value in
                guard let date = ISO8601DateFormatter().date(from: key) else { return nil }
                return HistoryGroup(id: key, date: date, items: value)
            }.sorted { $0.date > $1.date }
        } catch {
            // Not critical
        }
    }

    func deleteItem(_ id: String) {
        Task {
            do {
                let _: EmptyResponse = try await apiClient.apiRequest(
                    method: "DELETE",
                    path: "/chat/history/\(id)"
                )
                items.removeAll { $0.id == id }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    var filteredItems: [HistoryItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { $0.title?.localizedCaseInsensitiveContains(searchText) ?? false }
    }
}