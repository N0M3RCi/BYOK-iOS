import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showNewSpace = false
    @State private var newSpaceName = ""
    @State private var showAdmin = false
    @State private var showRemote = false
    @State private var showTriggers = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("M3RCI")
                            .font(.largeTitle.bold())
                        Text("AI Multi-Agent Workforce")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Quick Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            NavigationLink(destination: ChatView()) {
                                quickActionCard(icon: "message.fill", title: "New Chat", color: .accentTeal)
                            }
                            NavigationLink(destination: AgentsListView()) {
                                quickActionCard(icon: "person.2.fill", title: "Agents", color: .blue)
                            }
                            NavigationLink(destination: SettingsView()) {
                                quickActionCard(icon: "gearshape.fill", title: "Settings", color: .orange)
                            }
                            NavigationLink(destination: HistoryListView()) {
                                quickActionCard(icon: "clock.fill", title: "History", color: .purple)
                            }
                            NavigationLink(destination: KnowledgeBaseListView()) {
                                quickActionCard(icon: "books.vertical.fill", title: "Knowledge", color: .green)
                            }
                            NavigationLink(destination: UserStatsView()) {
                                quickActionCard(icon: "chart.bar.fill", title: "My Stats", color: .indigo)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Spaces
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Spaces")
                                .font(.headline)
                            Spacer()
                            Button(action: { showNewSpace = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentTeal)
                            }
                        }
                        .padding(.horizontal)

                        if viewModel.recentSpaces.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("No spaces yet")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(viewModel.recentSpaces) { space in
                                NavigationLink(destination: WorkspaceView(spaceID: space.id, spaceName: space.name)) {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.accentTeal)
                                        VStack(alignment: .leading) {
                                            Text(space.name)
                                                .fontWeight(.medium)
                                            Text("\(space.projectCount) projects")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Recent Projects
                    if !viewModel.recentProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Projects")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(viewModel.recentProjects) { item in
                                NavigationLink(destination: ChatView(projectID: item.projectId)) {
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(.secondary)
                                        VStack(alignment: .leading) {
                                            Text(item.title ?? "Untitled")
                                                .fontWeight(.medium)
                                            Text(item.createdAt)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Secondary navigation
                    VStack(spacing: 12) {
                        Button(action: { showTriggers = true }) {
                            navRow(icon: "bolt.fill", title: "Triggers", color: .yellow)
                        }
                        Button(action: { showRemote = true }) {
                            navRow(icon: "antenna.radiowaves.left.and.right", title: "Remote Control", color: .green)
                        }
                        if authViewModel.user?.role == .admin {
                            Button(action: { showAdmin = true }) {
                                navRow(icon: "person.3.fill", title: "Admin", color: .red)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemBackground))
            .sheet(isPresented: $showNewSpace) {
                createSpaceSheet
            }
            .sheet(isPresented: $showTriggers) {
                TriggersView()
            }
            .sheet(isPresented: $showRemote) {
                RemoteControlView()
            }
            .sheet(isPresented: $showAdmin) {
                AdminUsersView()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { authViewModel.logout() }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                viewModel.loadDashboard()
            }
        }
    }

    private func quickActionCard(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func navRow(icon: String, title: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var createSpaceSheet: some View {
        NavigationStack {
            Form {
                Section("Space Name") {
                    TextField("Enter space name", text: $newSpaceName)
                }
            }
            .navigationTitle("New Space")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showNewSpace = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await viewModel.createSpace(name: newSpaceName) }
                        showNewSpace = false
                        newSpaceName = ""
                    }
                    .disabled(newSpaceName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthViewModel())
        .environmentObject(ThemeManager())
}