import SwiftUI

struct WorkspaceView: View {
    @StateObject private var viewModel = WorkspaceViewModel()
    let spaceID: String
    let spaceName: String
    @State private var showFilePreview: FileItem?

    var body: some View {
        List {
            if viewModel.files.isEmpty {
                Text("No files")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
            ForEach(viewModel.files) { file in
                Button(action: { showFilePreview = file }) {
                    HStack {
                        Image(systemName: file.filename.fileIcon())
                            .foregroundColor(.accentTeal)
                        VStack(alignment: .leading) {
                            Text(file.filename).fontWeight(.medium)
                            Text(file.relativePath).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteFile(filename: file.filename, projectID: spaceID) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(spaceName)
        .sheet(item: $showFilePreview) { file in
            FilePreviewView(file: file)
        }
        .onAppear { viewModel.loadFiles(projectID: spaceID) }
    }
}

struct FilePreviewView: View {
    let file: FileItem
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentTeal)
                Text(file.filename).font(.title2)
                Text(file.relativePath).font(.caption).foregroundColor(.secondary)
                if let url = URL(string: file.url) {
                    Link("Open File", destination: url)
                        .padding()
                }
            }
            .navigationTitle("File Preview")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}