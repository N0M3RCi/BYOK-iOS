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
    @State private var systemPrompt: String
    @State private var selectedPlatform: String
    @State private var selectedModel: String
    @State private var showMemory = false
    @State private var memoryContent: String?

    init(agent: Agent, viewModel: AgentsViewModel) {
        self.agent = agent
        self.viewModel = viewModel
        _name = State(initialValue: agent.name)
        _description = State(initialValue: agent.description)
        _systemPrompt = State(initialValue: agent.systemPrompt ?? "")
        _selectedPlatform = State(initialValue: agent.customModelConfig?.platform ?? "")
        _selectedModel = State(initialValue: agent.customModelConfig?.modelType ?? "")
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
            }

            Section("System Prompt") {
                TextEditor(text: $systemPrompt)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if systemPrompt.isEmpty {
                            Text("Enter system prompt for this agent...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section("Model Configuration") {
                Picker("Platform", selection: $selectedPlatform) {
                    Text("Default").tag("")
                    ForEach(ModelPlatform.allCases, id: \.rawValue) { platform in
                        Text(platform.displayName).tag(platform.rawValue)
                    }
                }
                if !selectedPlatform.isEmpty {
                    Picker("Model", selection: $selectedModel) {
                        Text("Default").tag("")
                        ForEach(ModelType.allCases, id: \.rawValue) { model in
                            Text(model.displayName).tag(model.rawValue)
                        }
                    }
                }
            }

            Section("Tools") {
                if agent.tools.isEmpty {
                    Text("No tools assigned").foregroundColor(.secondary)
                }
                ForEach(agent.tools, id: \.self) { tool in
                    Label(tool, systemImage: "wrench.fill")
                }
                if let mcpTools = agent.mcpTools, !mcpTools.isEmpty {
                    ForEach(mcpTools, id: \.self) { tool in
                        Label(tool, systemImage: "server.rack")
                    }
                }
            }

            Section("Memory") {
                if let ms = agent.memorySettings {
                    LabeledContent("Enabled", value: ms.enabled ? "Yes" : "No")
                    if let maxTokens = ms.maxTokens {
                        LabeledContent("Max Tokens", value: "\(maxTokens)")
                    }
                } else {
                    Text("Memory not configured").foregroundColor(.secondary)
                }

                Button(action: {
                    showMemory = true
                    Task { await viewModel.fetchAgentMemory(agentName: agent.name) }
                }) {
                    Label("View Memory", systemImage: "brain")
                }

                if viewModel.agentMemory != nil {
                    Button(role: .destructive) {
                        Task { await viewModel.clearAgentMemory(agentName: agent.name) }
                    } label: {
                        Label("Clear Memory", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Edit Agent")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        let modelConfig: ModelConfig?
                        if selectedPlatform.isEmpty {
                            modelConfig = nil
                        } else {
                            modelConfig = ModelConfig(
                                platform: selectedPlatform,
                                modelType: selectedModel.isEmpty ? nil : selectedModel,
                                apiKey: agent.customModelConfig?.apiKey,
                                apiUrl: agent.customModelConfig?.apiUrl,
                                extraParams: agent.customModelConfig?.extraParams
                            )
                        }
                        let updated = Agent(
                            name: name,
                            description: description,
                            tools: agent.tools,
                            mcpTools: agent.mcpTools,
                            customModelConfig: modelConfig,
                            memorySettings: agent.memorySettings,
                            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
                        )
                        await viewModel.saveAgent(updated)
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showMemory) {
            memoryView
        }
    }

    private var memoryView: some View {
        NavigationStack {
            Group {
                if let memory = viewModel.agentMemory {
                    ScrollView {
                        Text(memory)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading memory...")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Agent Memory")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showMemory = false }
                }
            }
        }
    }
}