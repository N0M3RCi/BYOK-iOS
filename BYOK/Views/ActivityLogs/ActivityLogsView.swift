import SwiftUI

struct ActivityLogsView: View {
    @StateObject private var viewModel = ActivityLogsViewModel()
    var triggerId: String?

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.logs.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.logs.isEmpty {
                emptyStateView(icon: "list.bullet.clipboard", title: "No Activity", message: "Trigger execution logs will appear here")
            } else {
                ForEach(viewModel.logs) { log in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            statusIcon(log.status)
                            Text(log.action)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(log.createdAt)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let desc = log.description {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                        if let metadata = log.metadata, !metadata.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(Array(metadata.keys), id: \.self) { key in
                                        if let value = metadata[key] {
                                            Label("\(key): \(value)", systemImage: "tag")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color(.systemGray6))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Activity Logs")
        .onAppear {
            if let triggerId = triggerId {
                viewModel.loadLogs(triggerId: triggerId)
            } else {
                viewModel.loadAllLogs()
            }
        }
    }

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func statusIcon(_ status: String) -> some View {
        switch status {
        case "success", "completed":
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case "running", "in_progress":
            return Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.blue)
                .font(.caption)
        case "error", "failed":
            return Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
        default:
            return Image(systemName: "circle")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

#Preview {
    NavigationStack {
        ActivityLogsView()
    }
}