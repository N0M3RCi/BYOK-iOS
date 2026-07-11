import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showModelPicker = false
    @State private var showAttachmentPicker = false
    @State private var isShowingHistory = false
    var projectID: String?

    var body: some View {
        VStack(spacing: 0) {
            modelBar
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.messages.isEmpty { emptyState }
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message).id(message.id)
                        }
                        if viewModel.isLoading && viewModel.messages.isEmpty {
                            HStack { ProgressView(); Text("Thinking...").foregroundColor(.secondary).padding(.leading, 8) }.padding()
                        }
                    }.padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let last = viewModel.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            inputBar
        }
        .navigationTitle("Chat").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: { showModelPicker = true }) { Image(systemName: "cpu") }
                    Button(action: { isShowingHistory = true }) { Image(systemName: "clock.arrow.circlepath") }
                    if !viewModel.messages.isEmpty { Button(action: { viewModel.clearChat() }) { Image(systemName: "plus.bubble") } }
                }
            }
        }
        .sheet(isPresented: $showModelPicker) { modelPickerSheet }
        .sheet(isPresented: $isShowingHistory) { HistoryListView() }
        .sheet(isPresented: $showAttachmentPicker) { attachmentPickerSheet }
        .alert("Error", isPresented: .init(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) { Text(viewModel.errorMessage ?? "") }
    }

    private var modelBar: some View {
        HStack {
            Image(systemName: "cpu").font(.caption).foregroundColor(.accentTeal)
            Text(viewModel.modelDisplayName).font(.caption).fontWeight(.medium)
            Spacer()
            if viewModel.isStreaming {
                Button(action: { viewModel.stopStreaming() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill").font(.caption); Text("Stop").font(.caption)
                    }
                    .foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.red).cornerRadius(8)
                }
            }
        }
        .padding(.horizontal).padding(.vertical, 8).background(Color(.systemGray6))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 48)).foregroundColor(.accentTeal.opacity(0.5))
            Text("Start a conversation").font(.title3).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity)
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Button(action: { showAttachmentPicker = true }) { Image(systemName: "paperclip").font(.title3).foregroundColor(.secondary) }
                TextField("Type a message...", text: $viewModel.currentInput, axis: .vertical)
                    .textFieldStyle(.plain).padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(.systemGray6)).cornerRadius(20).lineLimit(1...5)
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                        .foregroundColor(viewModel.currentInput.isEmpty ? .gray : .accentTeal)
                }.disabled(viewModel.currentInput.isEmpty)
            }.padding(.horizontal, 12).padding(.vertical, 8)
        }.background(Color(.systemBackground))
    }

    private func sendMessage() {
        let text = viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if viewModel.messages.isEmpty { viewModel.startNewChat(question: text) }
        else { viewModel.sendFollowUp(question: text) }
    }

    private var modelPickerSheet: some View {
        NavigationStack {
            List {
                Section("Platform") {
                    ForEach(viewModel.availablePlatforms, id: \.self) { platform in
                        Button(action: { viewModel.selectedPlatform = platform }) {
                            HStack { Text(platform.displayName); Spacer(); if platform == viewModel.selectedPlatform { Image(systemName: "checkmark").foregroundColor(.accentTeal) } }
                        }.foregroundColor(.primary)
                    }
                }
                Section("Model") {
                    ForEach(viewModel.availableModels, id: \.self) { model in
                        Button(action: { viewModel.selectedModel = model }) {
                            HStack { Text(model.displayName); Spacer(); if model == viewModel.selectedModel { Image(systemName: "checkmark").foregroundColor(.accentTeal) } }
                        }.foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Select Model")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showModelPicker = false } } }
        }
    }

    private var attachmentPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Button(action: {}) { Label("Photo Library", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity).padding().background(Color(.systemGray6)).cornerRadius(12) }
                Button(action: {}) { Label("Documents", systemImage: "doc.fill").frame(maxWidth: .infinity).padding().background(Color(.systemGray6)).cornerRadius(12) }
                Button(action: {}) { Label("Camera", systemImage: "camera.fill").frame(maxWidth: .infinity).padding().background(Color(.systemGray6)).cornerRadius(12) }
                Spacer()
            }.padding().navigationTitle("Attach File")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cancel") { showAttachmentPicker = false } } }
        }
    }
}

#Preview {
    NavigationStack { ChatView().environmentObject(AuthViewModel()).environmentObject(ThemeManager()) }
}