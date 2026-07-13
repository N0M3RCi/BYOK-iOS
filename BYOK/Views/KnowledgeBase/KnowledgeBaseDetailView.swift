import SwiftUI
import UniformTypeIdentifiers

struct KnowledgeBaseDetailView: View {
    @StateObject private var viewModel = KnowledgeBaseViewModel()
    let knowledgeBase: KnowledgeBase
    @State private var showFilePicker = false
    @State private var showUploadError = false

    var body: some View {
        List {
            Section("Documents") {
                if viewModel.documents.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No documents yet")
                            .foregroundColor(.secondary)
                        Text("Upload PDF, TXT, MD, or DOCX files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }

                ForEach(viewModel.documents) { doc in
                    HStack(spacing: 12) {
                        Image(systemName: docIcon(for: doc.filename))
                            .foregroundColor(.accentTeal)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.filename)
                                .fontWeight(.medium)
                            if let size = doc.size {
                                Text(formatFileSize(size))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        statusBadge(doc.status)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { viewModel.deleteDocument(knowledgeBaseId: knowledgeBase.id, at: $0) }
            }

            Section {
                Button(action: { showFilePicker = true }) {
                    Label("Upload Document", systemImage: "icloud.and.arrow.up")
                }
                .disabled(viewModel.isUploading)

                if viewModel.isUploading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Uploading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(knowledgeBase.name)
        .onAppear { viewModel.loadDocuments(knowledgeBaseId: knowledgeBase.id) }
        .sheet(isPresented: $showFilePicker) {
            DocumentPickerView { data, filename in
                Task {
                    await viewModel.uploadDocument(
                        knowledgeBaseId: knowledgeBase.id,
                        data: data,
                        filename: filename
                    )
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.documents.isEmpty {
                ProgressView()
            }
        }
    }

    private func statusBadge(_ status: DocumentStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 6, height: 6)
            Text(status.rawValue.capitalized)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(statusColor(status).opacity(0.1))
        .cornerRadius(6)
    }

    private func statusColor(_ status: DocumentStatus) -> Color {
        switch status {
        case .indexed: return .green
        case .indexing: return .blue
        case .failed: return .red
        case .pending: return .orange
        }
    }

    private func docIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.viewfinder"
        case "txt": return "doc.plaintext"
        case "md": return "doc.text"
        case "docx", "doc": return "doc.richtext"
        case "csv", "xlsx", "xls": return "tablecells"
        default: return "doc.fill"
        }
    }

    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}