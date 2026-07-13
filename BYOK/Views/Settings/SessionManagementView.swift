import SwiftUI

struct SessionManagementView: View {
    @StateObject private var viewModel = SessionViewModel()

    var body: some View {
        List {
            Section {
                if viewModel.sessions.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "iphone")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No active sessions")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }

                ForEach(viewModel.sessions) { session in
                    HStack(spacing: 12) {
                        Image(systemName: session.platform == "ios" ? "iphone" : "laptopcomputer")
                            .foregroundColor(.accentTeal)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.deviceName ?? "Unknown Device")
                                .fontWeight(.medium)
                            if let platform = session.platform {
                                Text(platform)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let lastActive = session.lastActive {
                                Text("Last active: \(lastActive)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if session.isCurrent == true {
                            Text("Current")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        Task { await viewModel.revokeSession(viewModel.sessions[index].id) }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await viewModel.revokeAllSessions() }
                } label: {
                    Label("Revoke All Sessions", systemImage: "xmark.shield")
                }
                .disabled(viewModel.sessions.isEmpty)
            }
        }
        .navigationTitle("Sessions")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { viewModel.loadSessions() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear { viewModel.loadSessions() }
        .overlay {
            if viewModel.isLoading && viewModel.sessions.isEmpty {
                ProgressView()
            }
        }
    }
}

// MARK: - Session ViewModel
@MainActor
final class SessionViewModel: ObservableObject {
    @Published var sessions: [SessionInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    func loadSessions() {
        isLoading = true
        Task {
            do {
                let response: [SessionInfo] = try await apiClient.apiRequest(
                    method: "GET",
                    path: "/auth/sessions"
                )
                sessions = response
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func revokeSession(_ id: String) async {
        do {
            let _: EmptyResponse = try await apiClient.apiRequest(
                method: "DELETE",
                path: "/auth/sessions/\(id)"
            )
            loadSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revokeAllSessions() async {
        do {
            let _: EmptyResponse = try await apiClient.apiRequest(
                method: "DELETE",
                path: "/auth/sessions"
            )
            loadSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}