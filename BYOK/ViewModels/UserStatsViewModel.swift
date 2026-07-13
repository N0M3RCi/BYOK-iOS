import Foundation
import SwiftUI

@MainActor
final class UserStatsViewModel: ObservableObject {
    @Published var stats: UserStats?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    func loadStats() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            stats = try await apiClient.getUserStats()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var totalTokens: Int {
        guard let stats = stats else { return 0 }
        return stats.totalInputTokens + stats.totalOutputTokens
    }

    var formattedCost: String {
        guard let cost = stats?.totalCost else { return "N/A" }
        return String(format: "$%.4f", cost)
    }
}