import SwiftUI

struct TriggersView: View {
    @StateObject private var viewModel = TriggersViewModel()
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.triggers.isEmpty { Text("No triggers configured").foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 40) }
                ForEach(viewModel.triggers) { trigger in
                    HStack {
                        Image(systemName: triggerIcon(trigger.type)).foregroundColor(trigger.enabled ? .green : .gray).frame(width: 24)
                        VStack(alignment: .leading) { Text(trigger.name).fontWeight(.medium); Text(trigger.type).font(.caption).foregroundColor(.secondary) }
                        Spacer()
                        Toggle("", isOn: Binding(get: { trigger.enabled }, set: { _ in Task { await viewModel.toggleTrigger(trigger) } })).labelsHidden()
                        Button(action: { Task { await viewModel.executeTrigger(trigger.id) } }) { Image(systemName: "play.fill").font(.caption).foregroundColor(.accentTeal) }
                    }
                    .swipeActions(edge: .trailing) { Button(role: .destructive) { Task { await viewModel.deleteTrigger(trigger.id) } } label: { Label("Delete", systemImage: "trash") } }
                }
            }
            .navigationTitle("Triggers")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(action: { showCreate = true }) { Image(systemName: "plus") } } }
            .sheet(isPresented: $showCreate) { CreateTriggerView(viewModel: viewModel) }
            .onAppear { viewModel.loadTriggers() }
        }
    }

    private func triggerIcon(_ type: String) -> String {
        switch type { case "schedule": return "clock.fill"; case "webhook": return "link"; case "slack": return "s.circle"; default: return "bolt.fill" }
    }
}

struct CreateTriggerView: View {
    @ObservedObject var viewModel: TriggersViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""; @State private var type = "schedule"; @State private var schedule = ""; @State private var webhookUrl = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Trigger Details") { TextField("Name", text: $name); Picker("Type", selection: $type) { Text("Schedule").tag("schedule"); Text("Webhook").tag("webhook"); Text("Slack").tag("slack") } }
                if type == "schedule" { Section("Schedule") { TextField("Cron expression", text: $schedule) } }
                else if type == "webhook" { Section("Webhook") { TextField("Webhook URL", text: $webhookUrl).keyboardType(.URL).autocapitalization(.none) } }
            }
            .navigationTitle("Create Trigger")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create") { Task { await viewModel.createTrigger(name: name, type: type, config: TriggerConfig(schedule: schedule.isEmpty ? nil : schedule, webhookUrl: webhookUrl.isEmpty ? nil : webhookUrl, slackChannel: nil)) }; dismiss() }.disabled(name.isEmpty) }
            }
        }
    }
}