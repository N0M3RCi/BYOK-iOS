import SwiftUI

struct KnowledgeBaseAttachmentView: View {
    @StateObject private var viewModel = KnowledgeBaseViewModel()
    @Binding var selectedIds: [String]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.knowledgeBases.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No knowledge bases available")
                            .foregroundColor(.secondary)
                        Text("Create one from the Knowledge section")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                }

                ForEach(viewModel.knowledgeBases) { kb in
                    Button(action: { toggleSelection(kb.id) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(kb.name)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                if let desc = kb.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text("\(kb.documentCount) documents")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedIds.contains(kb.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentTeal)
                                    .font(.title3)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Attach Knowledge")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { viewModel.loadKnowledgeBases() }
        }
    }

    private func toggleSelection(_ id: String) {
        if let index = selectedIds.firstIndex(of: id) {
            selectedIds.remove(at: index)
        } else {
            selectedIds.append(id)
        }
    }
}