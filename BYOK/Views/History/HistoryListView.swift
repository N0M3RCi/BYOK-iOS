import SwiftUI

struct HistoryListView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var searchText = ""
    @State private var selectedItem: HistoryItem?
    @State private var showDeleteAlert = false
    @State private var deleteTarget: HistoryItem?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.filteredItems.isEmpty { Text("No chat history").foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 40) }
                ForEach(viewModel.filteredItems) { item in
                    Button(action: { selectedItem = item }) {
                        HStack {
                            Image(systemName: "bubble.left.and.text.bubble.fill").foregroundColor(.accentTeal)
                            VStack(alignment: .leading) { Text(item.title ?? "Untitled").fontWeight(.medium).lineLimit(1); Text(item.createdAt).font(.caption).foregroundColor(.secondary) }
                            Spacer()
                        }
                    }.foregroundColor(.primary)
                    .swipeActions(edge: .trailing) { Button(role: .destructive) { deleteTarget = item; showDeleteAlert = true } label: { Label("Delete", systemImage: "trash") } }
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search history...")
            .onChange(of: searchText) { newValue in viewModel.searchText = newValue }
            .sheet(item: $selectedItem) { item in HistoryDetailView(item: item) }
            .alert("Delete", isPresented: $showDeleteAlert) { Button("Cancel", role: .cancel) {}; Button("Delete", role: .destructive) { if let item = deleteTarget { viewModel.deleteItem(item.id) } } } message: { Text("Delete this conversation?") }
            .onAppear { viewModel.loadHistory() }
        }
    }
}

struct HistoryDetailView: View {
    let item: HistoryItem
    @Environment(\.dismiss) var dismiss
    @State private var messages: [ChatMessage] = []

    var body: some View {
        NavigationStack {
            Group {
                if messages.isEmpty {
                    VStack { ProgressView(); Text("Loading...").foregroundColor(.secondary) }
                } else {
                    List(messages) { msg in
                        VStack(alignment: .leading) {
                            Text(msg.role == .user ? "You" : "Assistant").font(.caption).fontWeight(.semibold).foregroundColor(.accentTeal)
                            Text(msg.content).font(.body)
                        }.padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(item.title ?? "Conversation")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                if !messages.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Share via System...") {
                                let text = messages.map { "\($0.role == .user ? "You" : "Assistant"): \($0.content)" }.joined(separator: "\n\n")
                                let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = scene.windows.first, let root = window.rootViewController {
                                    av.popoverPresentationController?.sourceView = root.view
                                    root.present(av, animated: true)
                                }
                            }
                            Button("Copy as Text") {
                                let text = messages.map { "\($0.role == .user ? "You" : "Assistant"): \($0.content)" }.joined(separator: "\n\n")
                                UIPasteboard.general.string = text
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    do {
                        let _: EmptyResponse = try await APIClient.shared.apiRequest(method: "GET", path: "/chat/history/\(item.id)")
                    } catch {}
                }
            }
        }
    }
}