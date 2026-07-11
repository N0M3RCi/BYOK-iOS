import SwiftUI

struct AdminUsersView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var selectedUser: AdminUser?
    @State private var showRoleEditor = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.users.isEmpty { Text("No users found").foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 40) }
                ForEach(viewModel.users) { user in
                    HStack {
                        Image(systemName: "person.circle.fill").font(.title2).foregroundColor(user.role == "admin" ? .red : .accentTeal)
                        VStack(alignment: .leading) {
                            Text(user.email).fontWeight(.medium)
                            HStack {
                                Text(user.role.capitalized).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(user.role == "admin" ? Color.red.opacity(0.1) : Color.gray.opacity(0.1)).cornerRadius(4)
                                if let limit = user.usageLimit { Text("Limit: \(limit)").font(.caption2).foregroundColor(.secondary) }
                            }
                        }
                        Spacer()
                        Menu {
                            Button("Edit Role") { selectedUser = user; showRoleEditor = true }
                            Divider()
                            Button(role: .destructive) { Task { await viewModel.deleteUser(id: user.id) } } label: { Label("Delete User", systemImage: "trash") }
                        } label: { Image(systemName: "ellipsis.circle").foregroundColor(.secondary) }
                    }.padding(.vertical, 4)
                }
            }
            .navigationTitle("Users (\(viewModel.users.count))")
            .onAppear { viewModel.loadUsers() }
            .sheet(isPresented: $showRoleEditor) { if let user = selectedUser { RoleEditorView(user: user, viewModel: viewModel) } }
        }
    }
}

struct RoleEditorView: View {
    let user: AdminUser
    @ObservedObject var viewModel: AdminViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("User") { LabeledContent("Email", value: user.email); LabeledContent("Current Role", value: user.role.capitalized) }
                Section("Change Role") {
                    Button("User") { Task { await viewModel.updateUserRole(id: user.id, role: "user") }; dismiss() }
                    Button("Admin") { Task { await viewModel.updateUserRole(id: user.id, role: "admin") }; dismiss() }
                }
                Section("Danger Zone") { Button(role: .destructive) { Task { await viewModel.deleteUser(id: user.id) }; dismiss() } label: { Label("Delete User", systemImage: "trash") } }
            }
            .navigationTitle("Edit User")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}