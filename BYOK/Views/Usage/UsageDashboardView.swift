import SwiftUI

struct UsageDashboardView: View {
    @StateObject private var viewModel = UsageViewModel()

    var body: some View {
        List {
            // Summary cards
            Section("Summary") {
                HStack {
                    summaryCard(
                        title: "Input Tokens",
                        value: viewModel.formatTokenCount(viewModel.totalInputTokens),
                        icon: "arrow.down.circle",
                        color: .blue
                    )
                    summaryCard(
                        title: "Output Tokens",
                        value: viewModel.formatTokenCount(viewModel.totalOutputTokens),
                        icon: "arrow.up.circle",
                        color: .green
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if viewModel.totalCost > 0 {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.yellow)
                        Text("Estimated Cost")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "$%.4f", viewModel.totalCost))
                            .fontWeight(.medium)
                    }
                }
            }

            // Period selector
            Section {
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(UsageViewModel.UsagePeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedPeriod) { _ in
                    viewModel.loadUsage()
                }
            }

            // Usage records
            Section("Usage Records") {
                if viewModel.usageRecords.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No usage data yet")
                            .foregroundColor(.secondary)
                        Text("Usage will appear after you start chatting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }

                ForEach(viewModel.usageRecords) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(record.providerName)
                                .fontWeight(.medium)
                            Spacer()
                            if let cost = record.cost, cost > 0 {
                                Text(String(format: "$%.4f", cost))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        HStack {
                            Label("↑\(viewModel.formatTokenCount(record.outputTokens))", systemImage: "arrow.up")
                                .font(.caption)
                                .foregroundColor(.green)
                            Label("↓\(viewModel.formatTokenCount(record.inputTokens))", systemImage: "arrow.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Spacer()
                            Text(record.modelType)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Usage")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.loadUsage() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear { viewModel.loadUsage() }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal, 4)
    }
}