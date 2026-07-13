import SwiftUI
import PhotosUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    let projectID: String?
    @State private var showFilePicker = false
    @State private var showFeedback = false
    @State private var feedbackMessageId: String?
    @State private var feedbackRating = 0
    @State private var showKnowledgeBasePicker = false
    @State private var showImagePicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []

    init(projectID: String? = nil) {
        self.projectID = projectID
        let vm = ChatViewModel()
        if let id = projectID {
            vm.currentProjectID = id
        }
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages List
                ScrollViewReader { proxy in
                    List {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                                .contextMenu {
                                    if message.role == .user && !message.isStreaming {
                                        Button("Edit") {
                                            viewModel.editMessage(id: message.id)
                                        }
                                        Button("Copy") {
                                            UIPasteboard.general.string = message.content
                                        }
                                    }
                                    if message.role == .assistant && !message.isStreaming {
                                        Button("Feedback") {
                                            feedbackMessageId = message.id
                                            showFeedback = true
                                        }
                                        Button("Copy") {
                                            UIPasteboard.general.string = message.content
                                        }
                                        Button("Regenerate") {
                                            viewModel.regenerateLastResponse()
                                        }
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: viewModel.messages.count) { _ in
                        if let last = viewModel.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                .overlay {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        emptyChatView
                    }
                    if let error = viewModel.errorMessage {
                        VStack {
                            HStack {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Spacer()
                                Button("X") { viewModel.errorMessage = nil }
                                    .font(.caption)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding()
                            Spacer()
                        }
                    }
                }

                // Input Area
                VStack(spacing: 0) {
                    // Edit mode indicator
                    if viewModel.editingMessageId != nil {
                        HStack {
                            Image(systemName: "pencil.line")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Editing message")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                            Button("Cancel") { viewModel.cancelEdit() }
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.08))
                    }

                    // Token usage
                    if let usage = viewModel.tokenUsage {
                        HStack {
                            Spacer()
                            Text("↑\(usage.input) ↓\(usage.output)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }

                    if !viewModel.attachedFiles.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.attachedFiles, id: \.self) { file in
                                    HStack {
                                        Image(systemName: "doc.fill")
                                            .font(.caption)
                                        Text(file)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 4)
                    }

                    HStack(spacing: 8) {
                        Button(action: { showFilePicker = true }) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 18))
                        }

                        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 5, matching: .images) {
                            Image(systemName: "photo")
                                .font(.system(size: 18))
                        }
                        .onChange(of: selectedPhotos) { newItems in
                            Task {
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self) {
                                        await viewModel.uploadFile(data: data, filename: "image.jpg")
                                    }
                                }
                                selectedPhotos = []
                            }
                        }

                        TextField(viewModel.editingMessageId != nil ? "Edit message..." : "Message...", text: $viewModel.currentInput)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)

                        if viewModel.isStreaming {
                            Button(action: { viewModel.stopStreaming() }) {
                                Image(systemName: "stop.fill")
                                    .foregroundColor(.red)
                            }
                            .keyboardShortcut(.escape, modifiers: [])
                        } else {
                            Button(action: sendMessage) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(viewModel.currentInput.isEmpty ? .gray : .accentTeal)
                            }
                            .disabled(viewModel.currentInput.isEmpty || viewModel.isLoading)
                            .keyboardShortcut(.return, modifiers: .command)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { viewModel.showModelPicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.caption)
                            Text(viewModel.modelDisplayName)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .foregroundColor(.accentTeal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentTeal.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Clear Chat") { viewModel.clearChat() }
                        Button("Upload File") { showFilePicker = true }
                        Button(action: { showKnowledgeBasePicker = true }) {
                            Label("Attach Knowledge", systemImage: "books.vertical")
                        }
                        Divider()
                        if !viewModel.messages.isEmpty {
                            Menu("Share") {
                                Button("Share via System...") { viewModel.shareConversation() }
                                Button("Copy as Text") { viewModel.copyConversationAsText() }
                                Button("Copy as Markdown") { viewModel.copyConversationAsMarkdown() }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showModelPicker) {
                modelPickerSheet
            }
            .sheet(isPresented: $showKnowledgeBasePicker) {
                KnowledgeBaseAttachmentView(selectedIds: $viewModel.attachedKnowledgeBaseIds)
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPickerView { data, filename in
                    Task { await viewModel.uploadFile(data: data, filename: filename) }
                }
            }
            .sheet(isPresented: $showFeedback) {
                if let messageId = feedbackMessageId {
                    feedbackView(messageId: messageId)
                }
            }
        }
    }

    private var emptyChatView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentTeal.opacity(0.5))
            Text("Start a conversation")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Type a message below to begin chatting with the AI")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var modelPickerSheet: some View {
        NavigationStack {
            Form {
                Section("Platform") {
                    Picker("Platform", selection: $viewModel.selectedPlatform) {
                        ForEach(ModelPlatform.allCases, id: \.self) { platform in
                            Text(platform.displayName).tag(platform)
                        }
                    }
                }
                Section("Model") {
                    Picker("Model", selection: $viewModel.selectedModel) {
                        ForEach(ModelType.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                }
                Section {
                    Text("Selected: \(viewModel.modelDisplayName)")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Chat Model")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { viewModel.showModelPicker = false }
                }
            }
        }
    }

    private func sendMessage() {
        if viewModel.editingMessageId != nil {
            viewModel.submitEdit()
            return
        }
        let text = viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if viewModel.currentProjectID != nil {
            viewModel.sendFollowUp(question: text)
        } else {
            viewModel.startNewChat(question: text)
        }
    }

    private func feedbackView(messageId: String) -> some View {
        NavigationStack {
            Form {
                Section("Rate this response") {
                    Picker("Rating", selection: $feedbackRating) {
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("4").tag(4)
                        Text("5").tag(5)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Button("Submit Feedback") {
                        Task {
                            let _ = MessageFeedback(
                                messageId: messageId,
                                rating: feedbackRating
                            )
                        }
                        showFeedback = false
                    }
                }
            }
            .navigationTitle("Feedback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showFeedback = false }
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if let reasoning = message.reasoning, !reasoning.isEmpty {
                    Text(reasoning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .textSelection(.enabled)

                if message.isStreaming {
                    ProgressView()
                        .scaleEffect(0.5)
                }

                if let executions = message.taskExecutions, !executions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(executions) { execution in
                            HStack {
                                Circle()
                                    .fill(execution.status == "completed" ? Color.green : (execution.status == "running" ? Color.blue : Color.gray))
                                    .frame(width: 8, height: 8)
                                Text(execution.agentName ?? execution.agent ?? "Agent")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let progress = execution.progress {
                                    ProgressView(value: progress, total: 1.0)
                                        .scaleEffect(0.6)
                                }
                                Spacer()
                                Text(execution.status)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(12)
            .background(message.role == .user ? Color.accentTeal : Color(.systemGray5))
            .cornerRadius(16)

            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: (Data, String) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (Data, String) -> Void
        init(onPick: @escaping (Data, String) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            if let data = try? Data(contentsOf: url) {
                onPick(data, url.lastPathComponent)
            }
        }
    }
}