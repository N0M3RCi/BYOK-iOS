import SwiftUI

struct ToolsListView: View {
    @StateObject private var viewModel = ToolsViewModel()
    @State private var showInstallAlert = false
    @State private var installTarget: Tool?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.tools.isEmpty { Text("No tools available").foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 40) }
                ForEach(viewModel.tools) { tool in
                    HStack {
                        Image(systemName: toolIcon(tool.name)).foregroundColor(.accentTeal).frame(width: 24)
                        VStack(alignment: .leading) { Text(tool.name).fontWeight(.medium); Text(tool.description).font(.caption).foregroundColor(.secondary).lineLimit(2) }
                        Spacer()
                        if tool.installed { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                        else { Button("Install") { installTarget = tool; showInstallAlert = true }.buttonStyle(.borderedProminent).controlSize(.small).tint(.accentTeal) }
                    }.padding(.vertical, 4)
                    .swipeActions(edge: .trailing) { if tool.installed { Button(role: .destructive) { Task { await viewModel.removeTool(name: tool.name) } } label: { Label("Remove", systemImage: "trash") } } }
                }
            }
            .navigationTitle("Tools")
            .onAppear { viewModel.loadTools() }
            .alert("Install Tool", isPresented: $showInstallAlert) { Button("Cancel", role: .cancel) {}; Button("Install") { if let tool = installTarget { Task { await viewModel.installTool(name: tool.name) } } } } message: { Text("Install \(installTarget?.name ?? "")?") }
        }
    }

    private func toolIcon(_ name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("google"): return "g.circle"
        case let n where n.contains("slack"): return "s.circle"
        case let n where n.contains("github"): return "chevron.left.forwardslash.chevron.right"
        case let n where n.contains("search"): return "magnifyingglass"
        case let n where n.contains("browser"): return "globe"
        case let n where n.contains("terminal"): return "terminal"
        case let n where n.contains("notion"): return "note.text"
        default: return "wrench.fill"
        }
    }
}