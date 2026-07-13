import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var usageRecords: [ProviderUsage] = []
    @Published var summary: UsageSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPeriod: UsagePeriod = .week

    private let apiClient = APIClient.shared

    enum UsagePeriod: String, CaseIterable {
        case week = "week"
        case month = "month"
        case all = "all"

        var displayName: String {
            switch self {
            case .week: return "This Week"
            case .month: return "This Month"
            case .all: return "All Time"
            }
        }
    }

    func loadUsage() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                async let records: [ProviderUsage] = apiClient.apiRequest(
                    method: "GET",
                    path: "/usage?period=\(selectedPeriod.rawValue)"
                )
                async let summaryResult: UsageSummary = apiClient.apiRequest(
                    method: "GET",
                    path: "/usage/summary?period=\(selectedPeriod.rawValue)"
                )
                let (loadedRecords, loadedSummary) = try await (records, summaryResult)
                usageRecords = loadedRecords
                summary = loadedSummary
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    var totalInputTokens: Int { summary?.totalInputTokens ?? usageRecords.reduce(0) { $0 + $1.inputTokens } }
    var totalOutputTokens: Int { summary?.totalOutputTokens ?? usageRecords.reduce(0) { $0 + $1.outputTokens } }
    var totalCost: Double { summary?.totalCost ?? usageRecords.compactMap(\.cost).reduce(0, +) }

    func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}