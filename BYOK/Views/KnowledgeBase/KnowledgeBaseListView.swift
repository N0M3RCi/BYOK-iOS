import SwiftUI

struct KnowledgeBaseListView: View {
    @StateObject private var viewModel = KnowledgeBaseViewModel()
    @State private var showCreateSheet = false
    @State private var newKBName = ""
    @State private var newKBDescription = ""

    var body: some View {
        List {
            if viewModel.knowledgeBases.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentTeal.opacity(0.5))
                    Text("No Knowledge Bases")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Create a knowledge base to upload documents\nand enable RAG in your chats")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            }

            ForEach(viewModel.knowledgeBases) { kb in
                NavigationLink(destination: KnowledgeBaseDetailView(knowledgeBase: kb)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kb.name)
                            .fontWeight(.medium)
                        if let desc = kb.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                                .font(.caption2)
                            Text("\(kb.documentCount) documents")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .onDelete { viewModel.deleteKnowledgeBase(at: $0) }
        }
        .navigationTitle("Knowledge")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentTeal)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            createSheet
        }
        .onAppear { viewModel.loadKnowledgeBases() }
        .overlay {
            if viewModel.isLoading && viewModel.knowledgeBases.isEmpty {
                ProgressView()
            }
        }
    }

    private var createSheet: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Knowledge base name", text: $newKBName)
                }
                Section("Description (optional)") {
                    TextField("Brief description", text: $newKBDescription)
                }
            }
            .navigationTitle("New Knowledge Base")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newKBName = ""
                        newKBDescription = ""
                        showCreateSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await viewModel.createKnowledgeBase(name: newKBName, description: newKBDescription.isEmpty ? nil : newKBDescription)
                            newKBName = ""
                            newKBDescription = ""
                            showCreateSheet = false
                        }
                    }
                    .disabled(newKBName.isEmpty)
                }
            }
        }
    }
}