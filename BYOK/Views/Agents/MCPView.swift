import SwiftUI

struct MCPView: View {
    @ObservedObject var viewModel: AgentsViewModel
    @State private var showInstall = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.mcpServers.isEmpty { Text("No MCP servers configured").foregroundColor(.secondary) }
                ForEach(viewModel.mcpServers) { server in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.name).fontWeight(.medium)
                        Text("Command: \(server.command)").font(.caption).foregroundColor(.secondary)
                        if !server.args.isEmpty { Text("Args: \(server.args.joined(separator: " "))").font(.caption2).foregroundColor(.secondary) }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        Task {
                            let _: EmptyResponse? = try? await APIClient.shared.brainDelete(path: "/mcp/\(viewModel.mcpServers[index].name)")
                            viewModel.loadAll()
                        }
                    }
                }
            }
            .navigationTitle("MCP Servers")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(action: { showInstall = true }) { Image(systemName: "plus") } } }
            .sheet(isPresented: $showInstall) { InstallMCPView(viewModel: viewModel) }
        }
    }
}

struct InstallMCPView: View {
    @ObservedObject var viewModel: AgentsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var command = ""
    @State private var args = ""
    @State private var envKey = ""; @State private var envValue = ""
    @State private var envVars: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Details") { TextField("Name", text: $name); TextField("Command", text: $command); TextField("Arguments", text: $args) }
                Section("Environment") {
                    HStack { TextField("Key", text: $envKey); TextField("Value", text: $envValue); Button("Add") { if !envKey.isEmpty { envVars[envKey] = envValue; envKey = ""; envValue = "" } } }
                    ForEach(Array(envVars.keys), id: \.self) { Text("\($0)=\(envVars[$0] ?? "")").font(.caption) }
                }
            }
            .navigationTitle("Install MCP")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Install") {
                        Task {
                            let config = MCPConfig(command: command, args: args.split(separator: " ").map(String.init), env: envVars)
                            let _: EmptyResponse? = try? await APIClient.shared.brainPost(path: "/mcp/install", body: MCPInstallRequest(name: name, mcp: config))
                            viewModel.loadAll(); dismiss()
                        }
                    }.disabled(name.isEmpty || command.isEmpty)
                }
            }
        }
    }
}