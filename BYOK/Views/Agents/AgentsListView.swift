import SwiftUI

struct AgentsListView: View {
    @StateObject private var viewModel = AgentsViewModel()
    @State private var showCreateAgent = false
    @State private var showSkills = false
    @State private var showMCP = false

    var body: some View {
        NavigationStack {
            List {
                Section("Agents") {
                    if viewModel.agents.isEmpty { Text("No agents configured").foregroundColor(.secondary) }
                    ForEach(viewModel.agents) { agent in
                        NavigationLink(destination: AgentDetailView(agent: agent, viewModel: viewModel)) {
                            HStack {
                                Image(systemName: "person.circle.fill").font(.title2).foregroundColor(.accentTeal)
                                VStack(alignment: .leading) {
                                    Text(agent.name).fontWeight(.medium)
                                    Text(agent.description).font(.caption).foregroundColor(.secondary).lineLimit(2)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet { Task { await viewModel.deleteAgent(name: viewModel.agents[index].name) } }
                    }
                }
                Section("Management") {
                    Button(action: { showSkills = true }) { Label("Skills", systemImage: "book.fill").foregroundColor(.primary) }
                    Button(action: { showMCP = true }) { Label("MCP Servers", systemImage: "server.rack").foregroundColor(.primary) }
                }
            }
            .navigationTitle("Agents")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(action: { showCreateAgent = true }) { Image(systemName: "plus") } } }
            .sheet(isPresented: $showCreateAgent) { CreateAgentView(viewModel: viewModel) }
            .sheet(isPresented: $showSkills) { SkillsView(viewModel: viewModel) }
            .sheet(isPresented: $showMCP) { MCPView(viewModel: viewModel) }
            .onAppear { viewModel.loadAll() }
        }
    }
}

struct CreateAgentView: View {
    @ObservedObject var viewModel: AgentsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Agent Details") { TextField("Name", text: $name); TextField("Description", text: $description) }
            }
            .navigationTitle("Create Agent")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create") { Task { await viewModel.createAgent(name: name, description: description, tools: []); dismiss() } }.disabled(name.isEmpty) }
            }
        }
    }
}

struct AgentDetailView: View {
    let agent: Agent
    @ObservedObject var viewModel: AgentsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name: String
    @State private var description: String

    init(agent: Agent, viewModel: AgentsViewModel) { self.agent = agent; self.viewModel = viewModel; _name = State(initialValue: agent.name); _description = State(initialValue: agent.description) }

    var body: some View {
        Form {
            Section("Details") { TextField("Name", text: $name); TextField("Description", text: $description) }
            Section("Tools") { ForEach(agent.tools, id: \.self) { Label($0, systemImage: "wrench.fill") } }
            if let mc = agent.customModelConfig {
                Section("Model") { LabeledContent("Platform", value: mc.platform ?? "Default"); LabeledContent("Model", value: mc.modelType ?? "Default") }
            }
        }
        .navigationTitle("Edit Agent")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { let u = Agent(name: name, description: description, tools: agent.tools, mcpTools: agent.mcpTools, customModelConfig: agent.customModelConfig, memorySettings: agent.memorySettings); await viewModel.saveAgent(u); dismiss() } } } }
    }
}