import SwiftUI

struct UserStatsView: View {
    @StateObject private var viewModel = UserStatsViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red).font(.caption)
                Button("Retry") { Task { await viewModel.loadStats() } }
            } else if let stats = viewModel.stats {
                Section("Overview") {
                    StatRow(label: "Total Requests", value: "\(stats.totalRequests)", icon: "number")
                    StatRow(label: "Input Tokens", value: formatNumber(stats.totalInputTokens), icon: "arrow.up")
                    StatRow(label: "Output Tokens", value: formatNumber(stats.totalOutputTokens), icon: "arrow.down")
                    StatRow(label: "Total Tokens", value: formatNumber(viewModel.totalTokens), icon: "tuningfork")
                    StatRow(label: "Total Cost", value: viewModel.formattedCost, icon: "dollarsign")
                }

                if let daily = stats.dailyStats, !daily.isEmpty {
                    Section("Daily Activity") {
                        ForEach(daily) { day in
                            HStack {
                                Text(day.date)
                                    .font(.caption)
                                    .frame(width: 80, alignment: .leading)
                                VStack(spacing: 2) {
                                    ProgressView(value: Double(day.requests), total: Double(stats.totalRequests))
                                        .tint(.accentTeal)
                                    Text("\(day.requests) req · \(formatNumber(day.inputTokens + day.outputTokens)) tok")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } else {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .navigationTitle("My Statistics")
        .onAppear { Task { await viewModel.loadStats() } }
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentTeal)
                .frame(width: 20)
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}